import 'package:flutter/material.dart';

import '../l10n.dart';
import '../widgets/tactile_button.dart';

class PathwayHubScreen extends StatelessWidget {
  final VoidCallback onSelectSymptoms;
  final VoidCallback onSelectPrakriti;
  final VoidCallback? onSelectVitals;
  final VoidCallback? onBackToRegistration;
  /// The three labels the flow sent, in the patient's language. The flow translates these into
  /// all nine languages and this screen used to print its own Hindi instead.
  final String? symptomsLabel;
  final String? prakritiLabel;
  final String? vitalsLabel;
  final String language;

  const PathwayHubScreen({
    super.key,
    this.symptomsLabel,
    this.prakritiLabel,
    this.vitalsLabel,
    this.language = 'hi',
    required this.onSelectSymptoms,
    required this.onSelectPrakriti,
    this.onSelectVitals,
    this.onBackToRegistration,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final isBounded = constraints.hasBoundedHeight;

        final cards = [
          _HubPathway(
            title: symptomsLabel ?? 'OPD checkup',
            subtitle: 'OPD Checkup & Medicine',
            badge: 'General OPD',
            iconAsset: 'assets/icons/opd.png',
            fallbackIcon: Icons.medical_services_rounded,
            color: const Color(0xFF0D9488),
            onTap: onSelectSymptoms,
          ),
          _HubPathway(
            title: prakritiLabel ?? 'Prakriti assessment',
            subtitle: 'Ayurveda Prakriti Assessment',
            badge: 'AYUSH body type',
            iconAsset: 'assets/icons/ayurveda.png',
            fallbackIcon: Icons.spa_rounded,
            color: const Color(0xFF059669),
            onTap: onSelectPrakriti,
          ),
          if (onSelectVitals != null)
            _HubPathway(
              title: vitalsLabel ?? 'Smart vitals',
              subtitle: 'Camera Heart Rate Check',
              badge: 'Smart vitals',
              iconAsset: 'assets/icons/vitals.png',
              fallbackIcon: Icons.favorite_rounded,
              color: const Color(0xFF0284C7),
              onTap: onSelectVitals!,
            ),
        ];

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Headline
            Text(
              tr('select_service', language),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Responsive Layout: Row on wide, Column on narrow, scrollable when height is tight
            if (isBounded && constraints.maxHeight >= 400)
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: _buildCard(cards[i], isWide: true, height: null)),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Expanded(child: _buildCard(cards[i], isWide: false, height: null)),
                          ],
                        ],
                      ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _buildCard(cards[i], isWide: false, height: 76),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );

        return content;
      },
    );
  }

  Widget _buildCard(_HubPathway card, {required bool isWide, double? height}) {
    return TactileButton(
      onPressed: card.onTap,
      height: height ?? (isWide ? 140 : 84),
      borderColor: card.color.withAlpha(120),
      shadowColor: card.color.withAlpha(200),
      borderRadius: BorderRadius.circular(20),
      child: isWide
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    card.iconAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    cacheWidth: 160,
                    cacheHeight: 160,
                    errorBuilder: (_, _, _) => Icon(card.fallbackIcon, size: 48, color: card.color),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  card.subtitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: card.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    card.badge,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: card.color),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    card.iconAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                    cacheWidth: 150,
                    cacheHeight: 150,
                    errorBuilder: (_, _, _) => Icon(card.fallbackIcon, size: 36, color: card.color),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.subtitle,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0D9488), size: 16),
              ],
            ),
    );
  }
}

class _HubPathway {
  final String title;
  final String subtitle;
  final String badge;
  final String iconAsset;
  final IconData fallbackIcon;
  final Color color;
  final VoidCallback onTap;

  const _HubPathway({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.color,
    required this.onTap,
  });
}
