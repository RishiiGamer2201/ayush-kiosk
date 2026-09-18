import 'package:flutter/material.dart';
import '../widgets/tactile_button.dart';

class EmergencyScreen extends StatelessWidget {
  final List<String> redFlags;
  final VoidCallback onStaffAcknowledged;

  const EmergencyScreen({
    super.key,
    required this.redFlags,
    required this.onStaffAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Beacon Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDC2626), width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x20DC2626), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/warning.png',
                      width: 52,
                      height: 52,
                      cacheWidth: 150,
                      cacheHeight: 150,
                      errorBuilder: (_, _, _) => const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 48),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'आपातकालीन चेतावनी (EMERGENCY)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF991B1B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'गंभीर लक्षण पाए गए हैं। तुरंत अस्पताल स्टाफ से संपर्क करें।',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Red Flags List
            if (isBounded)
              Expanded(child: _buildFlagsList())
            else
              SizedBox(height: 200, child: _buildFlagsList()),

            const SizedBox(height: 10),

            // Staff Verification Button
            TactileButton(
              onPressed: onStaffAcknowledged,
              height: 56,
              isDestructive: true,
              borderRadius: BorderRadius.circular(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'स्टाफ़ द्वारा सत्यापित (Staff Verified) ✓',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        );

        return body;
      },
    );
  }

  Widget _buildFlagsList() {
    final flags = redFlags.isEmpty
        ? ['अत्यधिक सीने में दर्द (Severe Chest Pain)', 'सांस लेने में अत्यधिक कठिनाई (Critical Breathlessness)']
        : redFlags;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
      ),
      child: ListView.builder(
        itemCount: flags.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    flags[index],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
