import 'package:flutter/material.dart';

import '../l10n.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../widgets/tactile_button.dart';

class DocumentsScreen extends StatefulWidget {
  final String headline;
  final VoidCallback onScan;
  final VoidCallback onDone;
  final CameraService cameraService;
  final List<String> scannedLines;
  final bool isScanning;
  final String? scanError;

  /// The language the patient chose; this screen's own words follow it.
  final String language;

  const DocumentsScreen({
    super.key,
    required this.headline,
    required this.onScan,
    required this.onDone,
    required this.cameraService,
    this.language = 'hi',
    this.scannedLines = const [],
    this.isScanning = false,
    this.scanError,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _showScannerOnMobile = true;

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
                      const Icon(Icons.document_scanner_rounded, color: Colors.white54, size: 40),
                      const SizedBox(height: 8),
                      Text(tr('hold_paper', widget.language), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              // Scanner button
              Positioned(
                bottom: 8,
                left: 14,
                right: 14,
                child: TactileButton(
                  onPressed: widget.onScan,
                  height: 44,
                  backgroundColor: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.isScanning ? tr('scanning', widget.language) : tr('capture_doc', widget.language),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final linesPane = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 20),
                  const SizedBox(width: 8),
                  Text(tr('ocr_text', widget.language), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${widget.scannedLines.length} ${tr('lines', widget.language)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: widget.scannedLines.isEmpty
                    ? Center(
                        child: Text(
                          tr('no_documents', widget.language),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.scannedLines.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                              Expanded(
                                child: Text(
                                  widget.scannedLines[index],
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
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
                      'assets/icons/prescription.png',
                      width: 28,
                      height: 28,
                      cacheWidth: 100,
                      cacheHeight: 100,
                      errorBuilder: (_, _, _) => const Icon(Icons.file_present_rounded, color: Color(0xFF0D9488), size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.headline.isEmpty ? tr('documents_title', widget.language) : widget.headline,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TactileButton(
                    onPressed: widget.onDone,
                    height: 36,
                    isSuccess: true,
                    borderRadius: BorderRadius.circular(10),
                    child: Text('${tr('done', widget.language)} ✓', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      onPressed: () => setState(() => _showScannerOnMobile = true),
                      isSelected: _showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: Text('📷 ${tr('capture_doc', widget.language)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton(
                      onPressed: () => setState(() => _showScannerOnMobile = false),
                      isSelected: !_showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: Text('📄 ${tr('doc_list_tab', widget.language)} (${widget.scannedLines.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                          Expanded(flex: 5, child: cameraPane),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: linesPane),
                        ],
                      )
                    : (_showScannerOnMobile ? cameraPane : linesPane),
              )
            else
              SizedBox(height: 280, child: cameraPane),
          ],
        );

        return body;
      },
    );
  }
}
