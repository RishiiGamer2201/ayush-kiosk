import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/models.dart';
import '../services/camera_service.dart';
import '../widgets/tactile_button.dart';

class RegistrationScreen extends StatefulWidget {
  final PatientProfile initialProfile;
  final CameraService cameraService;
  final ValueChanged<PatientProfile> onRegister;
  final VoidCallback onScanCard;
  final bool isScanning;
  final String? scanError;

  const RegistrationScreen({
    super.key,
    required this.initialProfile,
    required this.cameraService,
    required this.onRegister,
    required this.onScanCard,
    this.isScanning = false,
    this.scanError,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _abhaController;
  String _selectedGender = 'Male';
  bool _showScannerOnMobile = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _ageController = TextEditingController(text: widget.initialProfile.age?.toString() ?? '');
    _abhaController = TextEditingController(text: widget.initialProfile.abhaNumber ?? '');
    _selectedGender = widget.initialProfile.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _abhaController.dispose();
    super.dispose();
  }

  void _submit() {
    final profile = PatientProfile(
      name: _nameController.text.trim().isEmpty ? 'Patient / मरीज़' : _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 35,
      gender: _selectedGender,
      abhaNumber: _abhaController.text.trim().isEmpty ? null : _abhaController.text.trim(),
      isWalkIn: _abhaController.text.trim().isEmpty,
    );
    widget.onRegister(profile);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final isBounded = constraints.hasBoundedHeight;

        final formContent = Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Name Input
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'मरीज़ का नाम (Patient Name)',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0D9488)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            // Age Input with Steppers
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'उम्र (Age in Years)',
                      prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF0D9488)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  onPressed: () {
                    final curr = int.tryParse(_ageController.text) ?? 30;
                    if (curr > 1) _ageController.text = (curr - 1).toString();
                  },
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(12),
                  child: const Text('−', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                TactileButton(
                  onPressed: () {
                    final curr = int.tryParse(_ageController.text) ?? 30;
                    if (curr < 120) _ageController.text = (curr + 1).toString();
                  },
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(12),
                  child: const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            // Gender Selector 3D Pills
            Row(
              children: [
                _buildGenderPill('Male', 'पुरुष (M)', Icons.male_rounded),
                const SizedBox(width: 8),
                _buildGenderPill('Female', 'महिला (F)', Icons.female_rounded),
                const SizedBox(width: 8),
                _buildGenderPill('Other', 'अन्य (O)', Icons.transgender_rounded),
              ],
            ),

            // ABHA Number
            TextField(
              controller: _abhaController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'ABHA / आधार संख्या (वैकल्पिक Optional)',
                prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF0D9488)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        );

        final cameraContent = Container(
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
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 40),
                      SizedBox(height: 8),
                      Text('कैमरा स्कैनर तैयार है', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              // Scanner Guidelines
              Center(
                child: Container(
                  width: 200,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF5EEAD4), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Scan Button overlay
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
                      const Icon(Icons.camera_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.isScanning ? 'स्कैन हो रहा है...' : 'कार्ड स्कैन करें (Scan ID)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final body = Column(
          children: [
            // Top Title
            const Text(
              'मरीज़ का विवरण भरें (Patient Registration)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),

            if (!isWide) ...[
              const SizedBox(height: 6),
              // Tab Toggle on narrow screens
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      onPressed: () => setState(() => _showScannerOnMobile = false),
                      isSelected: !_showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: const Text('👤 मरीज़ विवरण (Form)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton(
                      onPressed: () => setState(() => _showScannerOnMobile = true),
                      isSelected: _showScannerOnMobile,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                      child: const Text('📷 कार्ड स्कैन (Scan)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Form Area
            if (isBounded)
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: formContent),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: cameraContent),
                        ],
                      )
                    : (_showScannerOnMobile ? cameraContent : formContent),
              )
            else
              SizedBox(
                height: 280,
                child: formContent,
              ),

            const SizedBox(height: 8),

            // Bottom Submit Button
            TactileButton(
              onPressed: _submit,
              height: 52,
              isSuccess: true,
              borderRadius: BorderRadius.circular(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'मरीज़ जोड़ें व आगे बढ़ें (Register & Continue) ➔',
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

  Widget _buildGenderPill(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: TactileButton(
        onPressed: () => setState(() => _selectedGender = value),
        isSelected: isSelected,
        height: 44,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF0D9488)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
