import 'package:flutter/material.dart';
import '../widgets/tactile_button.dart';

class ProblemScreen extends StatelessWidget {
  final String? selectedComplaint;
  final ValueChanged<String> onSelectComplaint;
  final VoidCallback onShowOnBody;
  final VoidCallback onSpeak;
  final bool isListening;

  const ProblemScreen({
    super.key,
    this.selectedComplaint,
    required this.onSelectComplaint,
    required this.onShowOnBody,
    required this.onSpeak,
    this.isListening = false,
  });

  @override
  Widget build(BuildContext context) {
    final complaints = [
      {
        'id': 'headache',
        'title': 'सिर दर्द',
        'subtitle': 'Headache',
        'asset': 'assets/icons/headache.png',
        'fallbackIcon': Icons.face_retouching_natural_rounded,
      },
      {
        'id': 'cough',
        'title': 'खांसी-जुकाम',
        'subtitle': 'Cough & Cold',
        'asset': 'assets/icons/cough.png',
        'fallbackIcon': Icons.air_rounded,
      },
      {
        'id': 'stomach',
        'title': 'पेट दर्द',
        'subtitle': 'Stomach Ache',
        'asset': 'assets/icons/stomach.png',
        'fallbackIcon': Icons.healing_rounded,
      },
      {
        'id': 'joint',
        'title': 'जोड़ों का दर्द',
        'subtitle': 'Joint / Knee Pain',
        'asset': 'assets/icons/joint.png',
        'fallbackIcon': Icons.accessibility_new_rounded,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        final bool canFlex = isBounded && constraints.maxHeight >= 360;

        Widget buildContent({required bool useFlex}) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Split: Voice vs Show on Body
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      onPressed: onSpeak,
                      height: 52,
                      backgroundColor: isListening ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDFA),
                      borderColor: isListening ? const Color(0xFF60A5FA) : const Color(0xFF5EEAD4),
                      shadowColor: isListening ? const Color(0xFF3B82F6) : const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 22,
                            color: isListening ? const Color(0xFF2563EB) : const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isListening ? 'बोलिए... (Listening)' : 'बोलकर बताएं (Speak)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isListening ? const Color(0xFF1D4ED8) : const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TactileButton(
                      onPressed: onShowOnBody,
                      height: 52,
                      backgroundColor: const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFFDE68A),
                      shadowColor: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.accessibility_rounded, size: 22, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text(
                            'शरीर पर दिखाएं (Body Map)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Headline
              const Text(
                'आपको क्या तकलीफ है? (Select Main Problem)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // 2x2 Grid
              if (useFlex)
                Expanded(child: _buildGrid(complaints))
              else
                SizedBox(height: 160, child: _buildGrid(complaints)),
            ],
          );
        }

        if (canFlex) {
          return buildContent(useFlex: true);
        } else {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: buildContent(useFlex: false),
          );
        }
      },
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> complaints) {
    return LayoutBuilder(
      builder: (context, gridBox) {
        final double spacing = 10.0;
        final double itemHeight = (gridBox.maxHeight - spacing) / 2;
        final bool canFit = itemHeight > 58;
        final double effectiveHeight = canFit ? itemHeight : 72;

        return GridView.builder(
          physics: canFit ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: effectiveHeight,
          ),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final item = complaints[index];
            final id = item['id'] as String;
            final isSelected = selectedComplaint == id;

            return TactileButton(
              onPressed: () => onSelectComplaint(id),
              isSelected: isSelected,
              height: effectiveHeight,
              borderRadius: BorderRadius.circular(18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 3D Clean PNG Icon (Never overflows)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item['asset'] as String,
                      width: effectiveHeight * 0.55,
                      height: effectiveHeight * 0.55,
                      fit: BoxFit.contain,
                      cacheWidth: 150,
                      cacheHeight: 150,
                      errorBuilder: (_, _, _) => Icon(
                        item['fallbackIcon'] as IconData,
                        size: effectiveHeight * 0.45,
                        color: isSelected ? Colors.white : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
