import 'package:flutter/material.dart';

import '../l10n.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../widgets/tactile_button.dart';

class AbhaScreen extends StatefulWidget {
  final String headline;
  final ValueChanged<String> onSubmitAbha;
  /// Null when the number is required, and then no Skip is drawn at all.
  final VoidCallback? onSkip;
  final CameraService cameraService;
  final VoidCallback onScanCard;
  final bool isScanning;
  final String? scanError;

  /// The language the patient chose; this screen's own words follow it.
  final String language;

  const AbhaScreen({
    super.key,
    required this.headline,
    required this.onSubmitAbha,
    this.onSkip,
    required this.cameraService,
    this.language = 'hi',
    required this.onScanCard,
    this.isScanning = false,
    this.scanError,
  });

  @override
  State<AbhaScreen> createState() => _AbhaScreenState();
}

class _AbhaScreenState extends State<AbhaScreen> {
  String _digits = '';
  bool _showScannerOnMobile = false;
  // The card prints two identities - a 14-digit number and an address like name@abdm - and
  // the patient gives whichever they can read out. Either is accepted by the server as is.
  bool _byAddress = false;
  final TextEditingController _address = TextEditingController();

  static final RegExp _addressShape = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,62}@[A-Za-z]{2,10}$');

  bool get _addressValid => _addressShape.hasMatch(_address.text.trim());

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _addDigit(String d) {
    if (_digits.length < 14) {
      setState(() => _digits += d);
    }
  }

  void _backspace() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  String get _formattedAbha {
    final buffer = StringBuffer();
    for (int i = 0; i < _digits.length; i++) {
      if (i > 0 && (i == 2 || i == 6 || i == 10)) {
        buffer.write('-');
      }
      buffer.write(_digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final isBounded = constraints.hasBoundedHeight;

        final cameraPane = Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF0D9488), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.cameraService.controller?.value.isInitialized == true)
                CameraPreview(widget.cameraService.controller!)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: Colors.white54, size: 40),
                      const SizedBox(height: 8),
                      Text(tr('abha_hold_card', widget.language), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              // Card guide
              Center(
                child: Container(
                  width: 200,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF5EEAD4), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Scan Button
              Positioned(
                bottom: 8,
                left: 12,
                right: 12,
                child: TactileButton(
                  onPressed: widget.onScanCard,
                  height: 44,
                  backgroundColor: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.isScanning ? tr('scanning', widget.language) : tr('abha_scan_card', widget.language),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final addressPane = Column(
          children: [
            TextField(
              controller: _address,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) { if (_addressValid) widget.onSubmitAbha(_address.text.trim()); },
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D9488)),
              decoration: InputDecoration(
                hintText: tr('abha_address_hint', widget.language),
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF0D9488)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TactileButton(
              onPressed: _addressValid ? () => widget.onSubmitAbha(_address.text.trim()) : null,
              height: 52,
              isSuccess: true,
              borderRadius: BorderRadius.circular(14),
              child: const Icon(Icons.check_rounded, size: 26, color: Colors.white),
            ),
          ],
        );

        final identityToggle = Row(
          children: [
            Expanded(
              child: TactileButton(
                onPressed: () => setState(() => _byAddress = false),
                isSelected: !_byAddress,
                height: 40,
                borderRadius: BorderRadius.circular(10),
                child: Text(tr('abha_14_digits', widget.language),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TactileButton(
                onPressed: () => setState(() => _byAddress = true),
                isSelected: _byAddress,
                height: 40,
                borderRadius: BorderRadius.circular(10),
                child: Text(tr('abha_address_tab', widget.language),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        );

        final keypadPane = Column(
          children: [
            identityToggle,
            const SizedBox(height: 4),
            Text(tr('abha_either', widget.language),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            if (_byAddress) addressPane else ...[
            // Display box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Text(
                _digits.isEmpty ? tr('abha_14_digits', widget.language) : _formattedAbha,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _digits.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0D9488),
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            // Clamped Keypad Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, kbBox) {
                  final double kHeight = (kbBox.maxHeight - 12) / 4;
                  final bool fits = kHeight > 36;
                  final double buttonHeight = fits ? kHeight : 42;
                  return GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: kbBox.maxWidth / (3 * buttonHeight),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 6,
                    physics: fits ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    children: [
                      for (int i = 1; i <= 9; i++)
                        TactileButton(
                          onPressed: () => _addDigit('$i'),
                          height: 40,
                          borderRadius: BorderRadius.circular(12),
                          child: Text('$i', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                      TactileButton(
                        onPressed: _backspace,
                        height: 40,
                        backgroundColor: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(Icons.backspace_outlined, size: 20, color: Color(0xFFDC2626)),
                      ),
                      TactileButton(
                        onPressed: () => _addDigit('0'),
                        height: 40,
                        borderRadius: BorderRadius.circular(12),
                        child: const Text('0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      TactileButton(
                        onPressed: _digits.length == 14 ? () => widget.onSubmitAbha(_digits) : null,
                        height: 40,
                        isSuccess: true,
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(Icons.check_rounded, size: 22, color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
            ],
          ],
        );

        final body = Column(
          children: [
            // Top Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0D9488).withAlpha(80), width: 1.5),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/abha.png',
                      width: 28,
                      height: 28,
                      cacheWidth: 100,
                      cacheHeight: 100,
                      errorBuilder: (_, _, _) => const Icon(Icons.badge_rounded, color: Color(0xFF0D9488), size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.headline.isEmpty ? tr('abha_title', widget.language) : widget.headline,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      // Two lines: the headline now says what the ABHA is for, and a sentence
                      // cut to "It is used to find y..." tells the patient nothing.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onSkip != null)
                    TactileButton(
                      onPressed: widget.onSkip,
                      height: 34,
                      backgroundColor: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      child: Text(tr('skip', widget.language), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                ],
              ),
            ),

            if (!isWide) ...[
              const SizedBox(height: 6),
              // Mobile Tab Toggle
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      onPressed: () => setState(() => _showScannerOnMobile = false),
                      isSelected: !_showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: Text(tr('enter_number', widget.language), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton(
                      onPressed: () => setState(() => _showScannerOnMobile = true),
                      isSelected: _showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: Text(tr('scan_card_tab', widget.language), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Content Split
            if (isBounded)
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: cameraPane),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: keypadPane),
                        ],
                      )
                    : (_showScannerOnMobile ? cameraPane : keypadPane),
              )
            else
              SizedBox(height: 280, child: keypadPane),
          ],
        );

        return body;
      },
    );
  }
}
