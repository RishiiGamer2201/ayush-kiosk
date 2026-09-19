import 'package:flutter/material.dart';
import '../l10n.dart';
import 'tactile_button.dart';

enum BodyZone { head, chest, abdomen, back, arms, legs }

class BodyZoneData {
  final BodyZone zone;
  final String labelEn;
  final String labelHi;
  final IconData icon;
  final String commonComplaint;

  const BodyZoneData({
    required this.zone,
    required this.labelEn,
    required this.labelHi,
    required this.icon,
    required this.commonComplaint,
  });

  /// The part's name in the patient's language - what gets written into their description.
  String label(String language) => tr('zone_${zone.name}', language);
}

const Map<BodyZone, BodyZoneData> bodyZoneMetadata = {
  BodyZone.head: BodyZoneData(
    zone: BodyZone.head,
    labelEn: 'Head / Eyes / Ears',
    labelHi: 'सिर / आँख / कान',
    icon: Icons.face,
    commonComplaint: 'severe headache and dizziness',
  ),
  BodyZone.chest: BodyZoneData(
    zone: BodyZone.chest,
    labelEn: 'Chest / Heart',
    labelHi: 'सीना / छाती / दिल',
    icon: Icons.favorite,
    commonComplaint: 'crushing chest pain',
  ),
  BodyZone.abdomen: BodyZoneData(
    zone: BodyZone.abdomen,
    labelEn: 'Stomach / Abdomen',
    labelHi: 'पेट / हाजमा',
    icon: Icons.medical_services_outlined,
    commonComplaint: 'severe abdominal stomach pain',
  ),
  BodyZone.back: BodyZoneData(
    zone: BodyZone.back,
    labelEn: 'Back / Spine',
    labelHi: 'पीठ / कमर',
    icon: Icons.accessibility_new,
    commonComplaint: 'severe lower back pain',
  ),
  BodyZone.arms: BodyZoneData(
    zone: BodyZone.arms,
    labelEn: 'Arms / Shoulders',
    labelHi: 'बाँह / कन्धा / हाथ',
    icon: Icons.front_hand,
    commonComplaint: 'arm and shoulder pain radiating',
  ),
  BodyZone.legs: BodyZoneData(
    zone: BodyZone.legs,
    labelEn: 'Legs / Knees / Feet',
    labelHi: 'पैर / घुटना',
    icon: Icons.directions_walk,
    commonComplaint: 'leg swelling and joint pain',
  ),
};


class BodyMapWidget extends StatefulWidget {
  final BodyZone? selectedZone;
  final ValueChanged<BodyZone> onZoneSelected;
  final String? selectedLaterality; // 'left', 'right', 'both'
  /// Null hides the side buttons. A button that does nothing when pressed teaches the
  /// patient the screen is broken.
  final ValueChanged<String>? onLateralitySelected;
  final String language;

  const BodyMapWidget({
    super.key,
    this.selectedZone,
    required this.onZoneSelected,
    this.selectedLaterality,
    this.onLateralitySelected,
    this.language = 'hi',
  });

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget> {
  bool _isBackView = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Top Toggle: Front vs Back View
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TactileButton(
                  onPressed: () => setState(() => _isBackView = false),
                  isSelected: !_isBackView,
                  height: 46,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(tr('front_view', widget.language), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TactileButton(
                  onPressed: () => setState(() => _isBackView = true),
                  isSelected: _isBackView,
                  height: 46,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flip_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(tr('back_view', widget.language), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Main Area: Interactive Silhouette + Laterality options
            Expanded(
              child: Row(
                children: [
                  // Silhouette Canvas Area
                  Expanded(
                    flex: 3,
                    child: Center(
                      // The figure and its tap zones are drawn at fixed pixel positions for a
                      // 160x310 canvas. Scaling the canvas, rather than the box, keeps the taps
                      // on the parts they belong to and the legs on screen whatever the height.
                      child: FittedBox(
                        child: SizedBox(
                        width: 160,
                        height: 310,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size.infinite,
                              painter: BodySilhouettePainter(isBackView: _isBackView),
                            ),
                            // Head
                            Positioned(
                              top: 20,
                              child: _buildZoneTap(
                                zone: BodyZone.head,
                                width: 70,
                                height: 70,
                                isCircle: true,
                              ),
                            ),
                            // Chest / Upper Back
                            Positioned(
                              top: 95,
                              child: _buildZoneTap(
                                zone: _isBackView ? BodyZone.back : BodyZone.chest,
                                width: 100,
                                height: 50,
                              ),
                            ),
                            // Abdomen / Lower Back
                            Positioned(
                              top: 150,
                              child: _buildZoneTap(
                                zone: _isBackView ? BodyZone.back : BodyZone.abdomen,
                                width: 90,
                                height: 45,
                              ),
                            ),
                            // Left Arm
                            Positioned(
                              top: 95,
                              left: 20,
                              child: _buildZoneTap(
                                zone: BodyZone.arms,
                                width: 35,
                                height: 95,
                              ),
                            ),
                            // Right Arm
                            Positioned(
                              top: 95,
                              right: 20,
                              child: _buildZoneTap(
                                zone: BodyZone.arms,
                                width: 35,
                                height: 95,
                              ),
                            ),
                            // Legs / Knees
                            Positioned(
                              top: 200,
                              child: _buildZoneTap(
                                zone: BodyZone.legs,
                                width: 100,
                                height: 90,
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),

                  // Right Side: Laterality selector buttons (Left / Right / Both)
                  if (widget.onLateralitySelected != null)
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'किस तरफ? (Side)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),
                        TactileButton(
                          onPressed: () => widget.onLateralitySelected?.call('left'),
                          isSelected: widget.selectedLaterality == 'left',
                          height: 52,
                          borderRadius: BorderRadius.circular(14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.west_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('बायाँ (Left)', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TactileButton(
                          onPressed: () => widget.onLateralitySelected?.call('right'),
                          isSelected: widget.selectedLaterality == 'right',
                          height: 52,
                          borderRadius: BorderRadius.circular(14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.east_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('दायाँ (Right)', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TactileButton(
                          onPressed: () => widget.onLateralitySelected?.call('both'),
                          isSelected: widget.selectedLaterality == 'both',
                          height: 52,
                          borderRadius: BorderRadius.circular(14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('दोनों (Both)', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoneTap({
    required BodyZone zone,
    required double width,
    required double height,
    bool isCircle = false,
  }) {
    final isSelected = widget.selectedZone == zone;
    return GestureDetector(
      onTap: () => widget.onZoneSelected(zone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          color: isSelected ? const Color(0xFFDC2626).withAlpha(190) : const Color(0xFF0D9488).withAlpha(40),
          border: Border.all(
            color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF0D9488).withAlpha(120),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x80EF4444),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class BodySilhouettePainter extends CustomPainter {
  final bool isBackView;
  BodySilhouettePainter({required this.isBackView});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    // Head
    canvas.drawCircle(Offset(cx, 55), 28, fill);
    canvas.drawCircle(Offset(cx, 55), 28, stroke);

    // Torso
    final torso = Path()
      ..moveTo(cx - 18, 86)
      ..lineTo(cx - 50, 105)
      ..lineTo(cx - 40, 195)
      ..lineTo(cx - 8, 205)
      ..lineTo(cx + 8, 205)
      ..lineTo(cx + 40, 195)
      ..lineTo(cx + 50, 105)
      ..lineTo(cx + 18, 86)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, stroke);

    // Arms
    final leftArm = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 72, 105, 18, 90), const Radius.circular(9));
    canvas.drawRRect(leftArm, fill);
    canvas.drawRRect(leftArm, stroke);

    final rightArm = RRect.fromRectAndRadius(Rect.fromLTWH(cx + 54, 105, 18, 90), const Radius.circular(9));
    canvas.drawRRect(rightArm, fill);
    canvas.drawRRect(rightArm, stroke);

    // Legs
    final leftLeg = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 36, 205, 28, 95), const Radius.circular(10));
    canvas.drawRRect(leftLeg, fill);
    canvas.drawRRect(leftLeg, stroke);

    final rightLeg = RRect.fromRectAndRadius(Rect.fromLTWH(cx + 8, 205, 28, 95), const Radius.circular(10));
    canvas.drawRRect(rightLeg, fill);
    canvas.drawRRect(rightLeg, stroke);
  }

  @override
  bool shouldRepaint(covariant BodySilhouettePainter oldDelegate) => oldDelegate.isBackView != isBackView;
}
