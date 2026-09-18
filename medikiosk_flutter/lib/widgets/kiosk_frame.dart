import 'package:flutter/material.dart';
import 'tactile_button.dart';

/// Universal Kiosk Frame enforcing single-screen viewport fit with ZERO scrolling.
/// Features fixed top bar, clamped content area, and fixed bottom control bar.
class KioskFrame extends StatelessWidget {
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onRepeatAudio;
  final VoidCallback? onStaffHelp;
  final VoidCallback? onSkip;
  final VoidCallback? onDontKnow;
  final VoidCallback? onSettings;
  final VoidCallback? onRestart;
  final bool isListening;
  final bool isConnected;
  final String? title;
  final String? currentStepLabel;

  const KioskFrame({
    super.key,
    required this.body,
    this.onBack,
    this.onNext,
    this.onRepeatAudio,
    this.onStaffHelp,
    this.onSkip,
    this.onDontKnow,
    this.onSettings,
    this.onRestart,
    this.isListening = false,
    this.isConnected = true,
    this.title,
    this.currentStepLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 ultra-clean clinical
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 550;

            return Column(
              children: [
                // Fixed Top Bar
                _buildTopBar(context, isNarrow),

                // Clamped Viewport Body - Strictly zero scrolling
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: body,
                  ),
                ),

                // Fixed Bottom Control Bar
                _buildBottomBar(context, isNarrow),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isNarrow) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          if (onBack != null)
            TactileButton(
              onPressed: onBack,
              height: 40,
              backgroundColor: const Color(0xFFF1F5F9),
              borderColor: const Color(0xFFCBD5E1),
              shadowColor: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF334155)),
                  if (!isNarrow) ...[
                    const SizedBox(width: 4),
                    const Text('वापस', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0D9488), size: 22),
            ),

          const SizedBox(width: 10),

          // Logo / Kiosk Branding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title ?? 'AYUSH',
                style: TextStyle(
                  fontSize: isNarrow ? 15 : 17,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0D9488),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                title != null ? '' : ' Kiosk',
                style: TextStyle(
                  fontSize: isNarrow ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Jetson Live Status Pill
          GestureDetector(
            onTap: onRestart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Jetson AI' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isConnected ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Spacer(),

          // Settings Button (if provided)
          if (onSettings != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: onSettings,
                tooltip: 'Settings',
              ),
            ),

          // Repeat Audio Button
          if (onRepeatAudio != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TactileButton(
                onPressed: onRepeatAudio,
                height: 40,
                backgroundColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFF5EEAD4),
                shadowColor: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up_rounded, size: 20, color: Color(0xFF0D9488)),
                    if (!isNarrow) ...[
                      const SizedBox(width: 4),
                      const Text('सुनें', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                    ],
                  ],
                ),
              ),
            ),

          // Staff Help Button (Red SOS)
          TactileButton(
            onPressed: onStaffHelp,
            height: 40,
            backgroundColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            shadowColor: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text(
                  isNarrow ? 'मदद' : 'कर्मचारी मदद',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isNarrow) {
    final skipCallback = onSkip ?? onDontKnow;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Don't Know / Skip Button
          if (skipCallback != null)
            TactileButton(
              onPressed: skipCallback,
              height: 44,
              backgroundColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFCBD5E1),
              shadowColor: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(14),
              child: Text(
                isNarrow ? '🤷 पता नहीं' : '🤷 मुझे नहीं पता (Skip)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            )
          else
            const SizedBox(width: 44),

          // Center Voice/Mic Status Wave
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isListening ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isListening ? const Color(0xFF60A5FA) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 18,
                    color: isListening ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isListening ? 'माइक चालू है' : 'आवाज तैयार',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isListening ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Next / Proceed Button
          TactileButton(
            onPressed: onNext,
            height: 44,
            backgroundColor: const Color(0xFF0D9488),
            borderColor: const Color(0xFF0F766E),
            shadowColor: const Color(0xFF115E59),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNarrow ? 'आगे ➔' : '✓ आगे बढ़ें (Next) ➔',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
