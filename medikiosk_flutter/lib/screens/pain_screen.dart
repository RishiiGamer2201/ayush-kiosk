import 'package:flutter/material.dart';
import '../widgets/tactile_button.dart';

class PainScreen extends StatelessWidget {
  final String? selectedSensation;
  final ValueChanged<String> onSelectSensation;
  final int? selectedSeverity;
  final ValueChanged<int> onSelectSeverity;

  const PainScreen({
    super.key,
    this.selectedSensation,
    required this.onSelectSensation,
    this.selectedSeverity,
    required this.onSelectSeverity,
  });

  @override
  Widget build(BuildContext context) {
    final sensations = [
      {'id': 'sharp', 'label': 'चुभन', 'sub': 'Sharp', 'icon': '💥', 'color': const Color(0xFFEF4444)},
      {'id': 'burning', 'label': 'जलन', 'sub': 'Burning', 'icon': '🔥', 'color': const Color(0xFFF97316)},
      {'id': 'dull', 'label': 'भारीपन', 'sub': 'Dull Ache', 'icon': '😣', 'color': const Color(0xFFEAB308)},
      {'id': 'throbbing', 'label': 'झटका', 'sub': 'Throbbing', 'icon': '⚡', 'color': const Color(0xFF8B5CF6)},
    ];

    final faces = [
      {'score': 2, 'label': 'थोड़ा', 'sub': 'Mild (1-3)', 'emoji': '🙂', 'color': const Color(0xFF22C55E)},
      {'score': 5, 'label': 'मध्यम', 'sub': 'Moderate (4-6)', 'emoji': '😐', 'color': const Color(0xFFEAB308)},
      {'score': 7, 'label': 'ज्यादा', 'sub': 'Severe (7-8)', 'emoji': '😣', 'color': const Color(0xFFF97316)},
      {'score': 10, 'label': 'बहुत ज्यादा', 'sub': 'Worst (9-10)', 'emoji': '😭', 'color': const Color(0xFFEF4444)},
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
              // Row 1 Title
              const Text(
                'दर्द कैसा महसूस होता है? (Pain Sensation)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Row 1: Sensation Cards
              if (useFlex)
                Expanded(flex: 5, child: _buildSensationRow(sensations))
              else
                SizedBox(height: 110, child: _buildSensationRow(sensations)),

              const SizedBox(height: 10),

              // Row 2 Title
              const Text(
                'दर्द कितना तेज है? (Wong-Baker Pain Scale)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Row 2: Faces Severity Scale
              if (useFlex)
                Expanded(flex: 6, child: _buildFacesRow(faces))
              else
                SizedBox(height: 130, child: _buildFacesRow(faces)),
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

  Widget _buildSensationRow(List<Map<String, dynamic>> sensations) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < sensations.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildSensationCard(sensations[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildSensationCard(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final isSelected = selectedSensation == id;
    final color = item['color'] as Color;

    return TactileButton(
      onPressed: () => onSelectSensation(id),
      isSelected: isSelected,
      borderColor: color.withAlpha(100),
      shadowColor: color.withAlpha(160),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item['icon'] as String, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            item['label'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
          ),
          Text(
            item['sub'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white70 : const Color(0xFF64748B),
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildFacesRow(List<Map<String, dynamic>> faces) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < faces.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildFaceCard(faces[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildFaceCard(Map<String, dynamic> item) {
    final score = item['score'] as int;
    final isSelected = selectedSeverity == score;
    final color = item['color'] as Color;

    return TactileButton(
      onPressed: () => onSelectSeverity(score),
      isSelected: isSelected,
      borderColor: color.withAlpha(120),
      shadowColor: color.withAlpha(180),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item['emoji'] as String, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            item['label'] as String,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
          ),
          Text(
            item['sub'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white70 : const Color(0xFF64748B),
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
