"""The pooled estimate trusts the windows that agree, not the whole trace."""

import numpy as np
import pytest

pytest.importorskip("numpy")

from medikiosk.edge import vitals


class _Result:
    def __init__(self, bpm, confident):
        self.bpm, self.confident = bpm, confident


def _trace(seconds=30.0, fs=30.0):
    t = np.arange(0, seconds, 1 / fs)
    data = np.column_stack(
        [t, np.full_like(t, 100.0), np.full_like(t, 120.0), np.full_like(t, 90.0), np.ones_like(t)]
    )
    return data


def test_agreeing_windows_give_a_confident_median_when_the_whole_trace_does_not() -> None:
    # The whole trace fails (the patient moved once); the still windows agree at ~72.
    def analyze(t, rgb, valid, win):
        if t[-1] - t[0] > vitals.ROLL_WINDOW_S + 1:
            return _Result(133.0, False), "ok"
        start = t[0]
        return (
            (_Result(71.0 + (start % 3), True), "ok")
            if 5 <= start <= 15
            else (None, "face not found")
        )

    bpm, confident, status, trusted, total = vitals.pooled_estimate(_trace(), 30.0, analyze)
    assert confident is True
    assert trusted >= 3 and total >= trusted
    assert 71 <= bpm <= 74
    assert status == "ok"


def test_windows_that_disagree_are_noise_and_fall_back_unconfident() -> None:
    def analyze(t, rgb, valid, win):
        if t[-1] - t[0] > vitals.ROLL_WINDOW_S + 1:
            return _Result(133.0, False), "ok"
        return _Result(50.0 + 10 * int(t[0]), True), "ok"  # 50, 60, 70 ... a harmonic hunt

    bpm, confident, *_ = vitals.pooled_estimate(_trace(), 30.0, analyze)
    assert confident is False
    assert bpm == 133.0


def test_too_few_trusted_windows_are_not_a_reading() -> None:
    def analyze(t, rgb, valid, win):
        if t[-1] - t[0] > vitals.ROLL_WINDOW_S + 1:
            return None, "face not found"
        return (_Result(72.0, True), "ok") if t[0] < 2 else (None, "face not found")

    bpm, confident, status, *_ = vitals.pooled_estimate(_trace(), 30.0, analyze)
    assert (bpm, confident, status) == (None, False, "face not found")
