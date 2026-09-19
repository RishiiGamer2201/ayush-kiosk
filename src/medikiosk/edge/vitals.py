"""One bounded heart-rate measurement from the kiosk camera, with no window on screen.

edge/heart_rate.py owns the signal work - face tracking, the skin mask, POS/CHROM and the
spectral estimate - but it is built around a live session: camera and processor threads, a CSV
log per run, and either an OpenCV window or an MJPEG server. A patient at the kiosk needs none of
that. They look at the camera for twenty seconds and get one number, and the camera closes again.

So this reuses that module's maths and supplies its own short capture loop. Nothing here is a
diagnosis: an unconfident estimate is reported as unconfident rather than rounded into a vital
sign, and staff review every record anyway.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import numpy as np

# Long enough for the estimator, which needs MIN_WINDOW_S (8 s) of clean signal and rejects
# stretches where the face was lost, and short enough that a patient will sit still for it.
# The analysis grid the pulse estimator resamples onto; breathing is read on the same grid.
FS = 30.0
MEASURE_S = 30.0
# Behind the intake nobody is waiting, so the trace can be longer; the patient is also moving,
# so the estimate is read off sliding windows and the trusted ones are pooled. A window of
# ROLL_WINDOW_S every ROLL_HOP_S, at least ROLL_MIN_CONFIDENT of them confident and within
# ROLL_MAX_SPREAD_BPM of each other (an interquartile range - a resting pulse does not wander
# further in a minute; a noise harmonic does).
BACKGROUND_MEASURE_S = 45.0
ROLL_WINDOW_S = 10.0
ROLL_HOP_S = 1.0
ROLL_MIN_CONFIDENT = 3
ROLL_MAX_SPREAD_BPM = 12.0

# Breathing band, in Hz: 0.1-0.5 is 6-30 breaths a minute. Anything slower is baseline drift,
# anything faster is movement rather than respiration.
BREATH_BAND = (0.1, 0.5)
# Below this the window cannot resolve the band well enough to report a number at all.
BREATH_MIN_WINDOW_S = 25.0
# How far the spectral peak must stand above the band's median before it is called confident.
BREATH_MIN_PROMINENCE = 3.0

# Exposure. These are calibration, not constants of nature: the right values depend on the lamp
# over the kiosk and on the camera, so they are named here to be re-tuned rather than hunted for.
#
# Measured on this board, indoors, with the patient lit only by room light: the camera's own
# auto-exposure left a face at green 36, under the 40 the pulse estimator needs, and two
# measurements a minute apart read 50.5 and 178.4 bpm - noise harmonics, not a pulse. With these,
# the same face reads green 119 and the same two runs read 68.6 and 62.4. A brighter room needs
# lower numbers; a dark one may need a lamp rather than more gain, which only amplifies noise.
CAMERA_BRIGHTNESS = 64
CAMERA_GAIN = 64

# One camera, one owner. A measurement holds this for its whole run; the preview takes it only
# when nobody is measuring, and otherwise shows the frame the measurement last stored.
_camera = threading.Lock()
_latest_lock = threading.Lock()
_latest_jpeg: bytes | None = None
_latest_face = False
_latest_at = 0.0
# The tablet polls the preview every 700 ms; encoding faster than this only costs frames.
PREVIEW_INTERVAL_S = 0.2


def _remember(frame, face_found: bool) -> None:
    """Keep a recent frame as a JPEG for the preview, without starving the measurement.

    Encoding every frame cost 1.6 of 13 frames a second - measured - and frames are what the pulse
    estimate is made of. The tablet polls this about once and a half a second, so encoding five
    times a second is already more than it can show.
    """

    global _latest_jpeg, _latest_face, _latest_at
    now = time.monotonic()
    if now - _latest_at < PREVIEW_INTERVAL_S:
        return
    try:
        import cv2

        ok, buffer = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 60])
    except Exception:  # noqa: BLE001 - a preview is never worth failing a measurement for
        return
    if not ok:
        return
    with _latest_lock:
        _latest_jpeg = buffer.tobytes()
        _latest_face = face_found
        _latest_at = now


def estimate_breathing(signal: np.ndarray, fs: float) -> tuple[float | None, bool, float]:
    """Breaths per minute from a uniformly sampled skin-colour trace, with its own confidence.

    The trace is detrended by subtracting its mean, windowed, and read in the breathing band only.
    Confidence is how far the peak stands above the median of that band: a real respiration shows
    as one clear ridge, while a patient shifting in their seat spreads energy across the whole
    band without a peak worth reporting.
    """

    if signal.size < int(BREATH_MIN_WINDOW_S * fs):
        return None, False, 0.0
    centred = signal - signal.mean()
    if not np.isfinite(centred).all() or centred.std() == 0:
        return None, False, 0.0
    spectrum = np.abs(np.fft.rfft(centred * np.hanning(centred.size)))
    freqs = np.fft.rfftfreq(centred.size, 1.0 / fs)
    band = (freqs >= BREATH_BAND[0]) & (freqs <= BREATH_BAND[1])
    if not band.any():
        return None, False, 0.0
    power = spectrum[band]
    peak = float(freqs[band][int(np.argmax(power))])
    median = float(np.median(power)) or 1e-9
    prominence = float(power.max() / median)
    return peak * 60.0, prominence >= BREATH_MIN_PROMINENCE, prominence


def _configure(cv2, capture) -> None:
    """Ask for MJPEG at 640x480/30.

    The default YUYV negotiation on this camera delivers about five frames a second - uncompressed
    640x480 at 30 fps does not fit the USB bus, so the driver quietly drops to a rate that does.
    MJPEG is compressed on the camera, so the same bus carries more than twice the frames, and
    frames are what the pulse estimate is made of. Failures are ignored: a camera that refuses
    these settings still works at whatever it chose.
    """

    try:
        capture.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        capture.set(cv2.CAP_PROP_FPS, 30)
        capture.set(cv2.CAP_PROP_BRIGHTNESS, CAMERA_BRIGHTNESS)
        capture.set(cv2.CAP_PROP_GAIN, CAMERA_GAIN)
    except Exception:  # noqa: BLE001 - a fussy driver is not a failed measurement
        pass


def preview_jpeg(camera: int | str = 0) -> tuple[bytes | None, bool]:
    """The current camera view as a JPEG, and whether a face was found in it.

    During a measurement this is whatever the capture loop last saw, which is the honest answer:
    the camera is busy and that frame is seconds old at most. Otherwise the camera is opened for
    one frame and released again, so aiming it does not require starting a measurement.
    """

    if _camera.acquire(blocking=False):
        try:
            import cv2

            capture = cv2.VideoCapture(camera)
            _configure(cv2, capture)
            try:
                if capture.isOpened():
                    for _ in range(3):  # the first frames off a USB camera are often black
                        ok, frame = capture.read()
                    if ok:
                        _remember(frame, False)
            finally:
                capture.release()
        except Exception:  # noqa: BLE001 - fall through to whatever was last stored
            pass
        finally:
            _camera.release()
    with _latest_lock:
        return _latest_jpeg, _latest_face


@dataclass(frozen=True)
class Vitals:
    """The outcome of one attempt. A rate is None unless there was a usable estimate of it.

    Heart rate and breath rate are judged separately: the pulse band is far easier to resolve in a
    short window than the breathing band, so a measurement routinely has a trustworthy pulse and
    no trustworthy respiration. Each carries its own confidence for that reason.
    """

    bpm: float | None
    confident: bool
    status: str
    breaths_per_min: float | None = None
    breath_confident: bool = False
    # How the verdict was reached: sliding windows the estimator trusted, out of how many.
    # In the log, this is the difference between "patient moved" and "camera pointed at a wall".
    windows_trusted: int = 0
    windows_total: int = 0
    face_seen: float = 0.0


def measure(camera: int | str = 0, seconds: float = MEASURE_S) -> Vitals:
    """Watch the camera for `seconds` and return a heart rate, or why there isn't one.

    Every failure is a status string, never an exception: a missing camera, a patient who looked
    away, or a face the tracker could not hold must leave the kiosk on the same screen, able to
    offer the measurement again or move on without it.
    """

    try:
        import cv2

        from medikiosk.edge.heart_rate import (
            MIN_SKIN_PX,
            FaceTracker,
            OneEuroFilter,
            SkinGate,
            analyze_window,
            face_mask,
        )
    except Exception as error:  # noqa: BLE001 - any import failure is "not available here"
        return Vitals(None, False, f"heart rate unavailable: {error}")

    if not _camera.acquire(timeout=5.0):
        return Vitals(None, False, "camera busy")
    capture = cv2.VideoCapture(camera)
    _configure(cv2, capture)
    if not capture.isOpened():
        capture.release()
        _camera.release()
        return Vitals(None, False, "camera unavailable")

    try:
        tracker = FaceTracker()
    except Exception as error:  # noqa: BLE001 - missing face model, no GPU, etc.
        capture.release()
        _camera.release()
        return Vitals(None, False, f"face tracking unavailable: {error}")

    gate, smoother = SkinGate(), OneEuroFilter()
    samples: list[tuple[float, float, float, float, float]] = []
    start = time.monotonic()
    frames = 0
    try:
        while time.monotonic() - start < seconds:
            ok, frame = capture.read()
            if not ok:
                break
            now = time.monotonic() - start
            height, width = frame.shape[:2]
            points = tracker.track(frame, now)
            rgb: tuple[float, float, float] = (np.nan, np.nan, np.nan)
            valid = False
            if points is None:
                smoother.reset()
            else:
                points = smoother(points, now)
                geometry = face_mask(points, height, width)
                if geometry is not None:
                    top, left, inside = geometry
                    crop = frame[top:top + inside.shape[0], left:left + inside.shape[1]]
                    ycc = cv2.cvtColor(crop, cv2.COLOR_BGR2YCrCb)
                    # The skin gate learns this patient's colour; it only needs occasional looks.
                    if frames % 10 == 0:
                        gate.observe(ycc[inside], now)
                    selected = gate.select(ycc, inside)
                    if int(selected.sum()) >= MIN_SKIN_PX:
                        rgb = tuple(crop[selected].mean(axis=0)[::-1])
                        valid = True
            samples.append((now, *rgb, float(valid)))
            # Publish as we go: this is what makes the camera aimable from the tablet.
            _remember(frame, valid)
            frames += 1
    except Exception as error:  # noqa: BLE001 - a capture fault is a failed measurement, not a crash
        return Vitals(None, False, f"measurement failed: {error}")
    finally:
        capture.release()
        tracker.close()
        _camera.release()

    if len(samples) < 2:
        return Vitals(None, False, "no frames from camera")
    data = np.asarray(samples, dtype=np.float64)
    bpm, confident, status, trusted, total = pooled_estimate(data, seconds, analyze_window)
    seen = float(data[:, 4].mean())

    # Breathing is read from the same trace, on its own terms: it survives a window too short or
    # too noisy for a pulse, and it fails on windows where the pulse came out fine.
    breaths, breath_ok, _prominence = None, False, 0.0
    valid = data[:, 4] > 0
    if valid.sum() > 1:
        times, green = data[valid, 0], data[valid, 2]
        span = float(times[-1] - times[0])
        if span >= BREATH_MIN_WINDOW_S:
            grid = np.arange(times[0], times[-1], 1.0 / FS)
            breaths, breath_ok, _prominence = estimate_breathing(
                np.interp(grid, times, green), FS
            )
            if breaths is not None:
                breaths = round(breaths, 1)

    if bpm is None:
        if seen < 0.5:
            status = "no face in view - point the camera at the patient's face"
        return Vitals(None, False, status, breaths, breath_ok, trusted, total, round(seen, 2))
    return Vitals(
        round(float(bpm), 1), confident, "ok", breaths, breath_ok, trusted, total, round(seen, 2)
    )


def pooled_estimate(
    data, seconds: float, analyze
) -> tuple[float | None, bool, str, int, int]:
    """Heart rate from the trusted sliding windows of a trace, falling back to the whole of it.

    Returns (bpm, confident, status, trusted windows, windows). Confident only when
    ROLL_MIN_CONFIDENT windows each passed the estimator's own SNR and POS/CHROM checks and
    agree with each other; then the median of them is the reading. Otherwise whatever a single pass over the whole trace says,
    which is never confident here - the whole trace failed for a reason.
    """

    t, rgb, valid = data[:, 0], data[:, 1:4], data[:, 4] > 0
    trusted: list[float] = []
    total = 0
    end = t[0] + ROLL_WINDOW_S
    while end <= t[-1] + 1e-9:
        mask = (t >= end - ROLL_WINDOW_S) & (t <= end)
        if mask.sum() >= 2:
            total += 1
            result, _ = analyze(t[mask], rgb[mask], valid[mask], ROLL_WINDOW_S)
            if result is not None and result.confident:
                trusted.append(float(result.bpm))
        end += ROLL_HOP_S
    if len(trusted) >= ROLL_MIN_CONFIDENT:
        q1, q3 = np.percentile(trusted, [25, 75])
        if q3 - q1 <= ROLL_MAX_SPREAD_BPM:
            return float(np.median(trusted)), True, "ok", len(trusted), total
    whole, status = analyze(t, rgb, valid, seconds)
    if whole is None:
        return None, False, status, len(trusted), total
    return float(whole.bpm), False, "ok", len(trusted), total
