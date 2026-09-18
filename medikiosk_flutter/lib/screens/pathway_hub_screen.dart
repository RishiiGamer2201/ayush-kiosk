import 'package:flutter/material.dart';
import '../widgets/tactile_button.dart';

class PathwayHubScreen extends StatelessWidget {
  final VoidCallback onSelectSymptoms;
  final VoidCallback onSelectPrakriti;
  final VoidCallback? onSelectVitals;
  final VoidCallback? onBackToRegistration;

  const PathwayHubScreen({
    super.key,
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
            title: 'बीमारी की जाँच',
            subtitle: 'OPD Checkup & Medicine',
            badge: 'प्राथमिक जाँच • General OPD',
            iconAsset: 'assets/icons/opd.png',
            fallbackIcon: Icons.medical_services_rounded,
            color: const Color(0xFF0D9488),
            onTap: onSelectSymptoms,
          ),
          _HubPathway(
            title: 'प्रकृति परीक्षण',
            subtitle: 'Ayurveda Prakriti Assessment',
            badge: 'आयुष निदान • AYUSH Body Type',
            iconAsset: 'assets/icons/ayurveda.png',
            fallbackIcon: Icons.spa_rounded,
            color: const Color(0xFF059669),
            onTap: onSelectPrakriti,
          ),
          if (onSelectVitals != null)
            _HubPathway(
              title: 'स्मार्ट वाइटल्स',
              subtitle: 'Camera Heart Rate Check',
              badge: 'कैमरा जाँच • Smart Vitals',
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
            const Text(
              'आप आज क्या करवाना चाहते हैं? (Select Service)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Responsive Layout: Row on wide, Column on narrow
            if (isBounded)
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: _buildCard(cards[i], isWide: true)),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Expanded(child: _buildCard(cards[i], isWide: false)),
                          ],
                        ],
                      ),
              )
            else
              SizedBox(
                height: 380,
                child: Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Expanded(child: _buildCard(cards[i], isWide: false)),
                    ],
                  ],
                ),
              ),
          ],
        );

        return content;
      },
    );
  }

  Widget _buildCard(_HubPathway card, {required bool isWide}) {
    return TactileButton(
      onPressed: card.onTap,
      height: 100, // TactileButton adjusts dynamically inside Expanded
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
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    cacheWidth: 150,
                    cacheHeight: 150,
                    errorBuilder: (_, _, _) => Icon(card.fallbackIcon, size: 40, color: card.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.subtitle,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0D9488), size: 18),
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
