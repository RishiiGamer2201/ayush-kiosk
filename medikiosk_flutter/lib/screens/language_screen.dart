import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/tactile_button.dart';

class LanguageScreen extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onRepeatAudio;
  final List<String>? codes;

  const LanguageScreen({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.onRepeatAudio,
    this.codes,
  });

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = supportedLanguages.where((lang) {
      if (codes == null || codes!.isEmpty) return true;
      final short = lang.code.split('-').first;
      return codes!.contains(short) || codes!.contains(lang.code);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice / Touch prompt header pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF99F6E4), width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'अपनी भाषा बोलें या चुनें (Speak or Touch)',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Clamped Grid
            if (isBounded)
              Expanded(child: _buildGrid(filteredLanguages))
            else
              SizedBox(height: 380, child: _buildGrid(filteredLanguages)),
          ],
        );

        return body;
      },
    );
  }

  Widget _buildGrid(List<LanguageItem> filteredLanguages) {
    return LayoutBuilder(
      builder: (context, gridBox) {
        final crossCount = gridBox.maxWidth > 650 ? 3 : (gridBox.maxWidth > 400 ? 3 : 2);
        final double spacing = 8.0;
        final int rows = (filteredLanguages.length / crossCount).ceil();
        final double itemHeight = (gridBox.maxHeight - (rows - 1) * spacing) / (rows > 0 ? rows : 1);
        final bool canFit = itemHeight > 48;
        final double effectiveHeight = canFit ? itemHeight : 56;

        return GridView.builder(
          physics: canFit ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: effectiveHeight,
          ),
          itemCount: filteredLanguages.length,
          itemBuilder: (context, index) {
            final lang = filteredLanguages[index];
            final short = lang.code.split('-').first;
            final isSelected = selectedLanguage == lang.code || selectedLanguage == short;

            return TactileButton(
              onPressed: () => onLanguageSelected(short),
              isSelected: isSelected,
              height: effectiveHeight,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Script Emblem circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withAlpha(50)
                          : const Color(0xFF0D9488).withAlpha(30),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      lang.scriptEmblem,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lang.englishName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
