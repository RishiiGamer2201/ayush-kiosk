import 'package:flutter/material.dart';
import '../l10n.dart';
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
  /// Staff-only settings are reached by holding the icon, so a patient cannot wander in.
  final bool settingsNeedsLongPress;
  final VoidCallback? onRestart;
  final bool isListening;
  /// True while the kiosk is speaking. Shown, because a patient who cannot tell whether the
  /// machine is talking or stuck will start pressing things.
  final bool isSpeaking;
  final bool isConnected;
  final String? title;
  final String? currentStepLabel;
  /// The language the patient chose. The bar and the footer are on every screen, so leaving them
  /// in one language put Hindi controls around a Tamil question.
  final String language;

  const KioskFrame({
    super.key,
    required this.body,
    this.language = 'hi',
    this.onBack,
    this.onNext,
    this.onRepeatAudio,
    this.onStaffHelp,
    this.onSkip,
    this.onDontKnow,
    this.onSettings,
    this.onRestart,
    this.isListening = false,
    this.isSpeaking = false,
    this.settingsNeedsLongPress = false,
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
                    Text(tr('back', language), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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

          const SizedBox(width: 8),

          // Actions on Right
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Settings Button (if provided)
                  if (onSettings != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      // A tap does nothing when this is staff-only: the dialog behind it carries
                      // the Jetson's address and a Connect button, and a patient waiting in a
                      // queue will press anything that presses. A disabled IconButton still
                      // swallows the gesture, so when it is staff-only there is no button here
                      // at all - just an icon that answers to being held.
                      child: settingsNeedsLongPress
                          ? InkWell(
                              onLongPress: onSettings,
                              borderRadius: BorderRadius.circular(24),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.settings_rounded, size: 20, color: Color(0xFF64748B)),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.settings_rounded, size: 20, color: Color(0xFF64748B)),
                              onPressed: onSettings,
                              tooltip: 'Settings',
                            ),
                    ),

                  // 1. Repeat Audio Button (सुनें)
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
                              Text(tr('listen', language), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // 2. Restart Button (फिर से शुरू / New Patient)
                  if (onRestart != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TactileButton(
                        onPressed: onRestart,
                        height: 40,
                        backgroundColor: const Color(0xFFFFFBEB),
                        borderColor: const Color(0xFFFDE68A),
                        shadowColor: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restart_alt_rounded, size: 20, color: Color(0xFFD97706)),
                            if (!isNarrow) ...[
                              const SizedBox(width: 4),
                              Text(tr('again', language), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // 3. Staff Help Button (मदद / Help SOS)
                  if (onStaffHelp != null)
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
                            tr('staff_help', language),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isNarrow) {
    final hasFooterControls = onDontKnow != null || onSkip != null;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Pata Nahi (Don't Know) Button
          if (onDontKnow != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TactileButton(
                  onPressed: onDontKnow,
                  height: 46,
                  backgroundColor: const Color(0xFFF8FAFC),
                  borderColor: const Color(0xFFCBD5E1),
                  shadowColor: const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr('dont_know', language),
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Skip Button
          if (onSkip != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TactileButton(
                  onPressed: onSkip,
                  height: 46,
                  backgroundColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  shadowColor: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.skip_next_rounded, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          tr('skip', language),
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // If none of the 4 quick response buttons are present, show center mic status
          if (!hasFooterControls)
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
                      isSpeaking
                          ? Icons.volume_up_rounded
                          : (isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                      size: 22,
                      color: isSpeaking
                          ? const Color(0xFF047857)
                          : (isListening ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isSpeaking
                            ? tr('speaking', language)
                            : (isListening ? tr('mic_on', language) : tr('voice_ready', language)),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSpeaking
                              ? const Color(0xFF047857)
                              : (isListening ? const Color(0xFF1D4ED8) : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Next / Proceed Button (if provided)
          if (onNext != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TactileButton(
                onPressed: onNext,
                height: 46,
                backgroundColor: const Color(0xFF0D9488),
                borderColor: const Color(0xFF0F766E),
                shadowColor: const Color(0xFF115E59),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tr('next', language)} ➔',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
