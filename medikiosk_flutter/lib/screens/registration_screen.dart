import 'package:flutter/material.dart';

import '../l10n.dart';
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

  /// The language the patient chose; this screen's own words follow it.
  final String language;

  /// Which of name, age or gender the flow is waiting for, so the patient can see where they
  /// are. Null when the flow is not asking for a particular one.
  final String? asking;

  const RegistrationScreen({
    super.key,
    required this.initialProfile,
    required this.cameraService,
    this.language = 'hi',
    this.asking,
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
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _ageController = TextEditingController(text: widget.initialProfile.age?.toString() ?? '');
    _abhaController = TextEditingController(text: widget.initialProfile.abhaNumber ?? '');
    _selectedGender = widget.initialProfile.gender;
  }

  @override
  void didUpdateWidget(RegistrationScreen old) {
    super.didUpdateWidget(old);
    // The flow echoes back what it has taken down, so a spoken answer appears in the form
    // instead of vanishing. A field the patient is typing in is left alone: their hand beats
    // an echo from the server.
    final profile = widget.initialProfile;
    if (!_nameFocus.hasFocus &&
        profile.name.isNotEmpty &&
        profile.name != _nameController.text) {
      _nameController.text = profile.name;
    }
    final age = profile.age?.toString() ?? '';
    if (!_ageFocus.hasFocus && age.isNotEmpty && age != _ageController.text) {
      _ageController.text = age;
    }
    if (profile.gender.isNotEmpty && profile.gender != _selectedGender) {
      _selectedGender = profile.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _abhaController.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  /// True once there is something real to send. Nothing is substituted for a blank: an invented
  /// age is indistinguishable from a given one on the sheet the doctor reads, and a patient who
  /// cannot answer has "I do not know" in the footer, which is what it is for.
  bool get _hasSomethingToSend =>
      _nameController.text.trim().isNotEmpty ||
      int.tryParse(_ageController.text.trim()) != null ||
      _selectedGender.isNotEmpty;

  String _askingLabel() => switch (widget.asking) {
        'name' => tr('patient_name', widget.language),
        'age' => tr('age_years', widget.language),
        'gender' => tr('gender', widget.language),
        _ => '',
      };

  void _submit() {
    final profile = PatientProfile(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
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

        Widget buildFormFields() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Input
              TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: tr('patient_name', widget.language),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0D9488)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              // Age Input with Steppers
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      focusNode: _ageFocus,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: tr('age_years', widget.language),
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
                      if (curr > 1) setState(() => _ageController.text = (curr - 1).toString());
                    },
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text('−', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  TactileButton(
                    onPressed: () {
                      final curr = int.tryParse(_ageController.text) ?? 29;
                      if (curr < 120) setState(() => _ageController.text = (curr + 1).toString());
                    },
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Gender Selector 3D Pills
              Row(
                children: [
                  _buildGenderPill('Male', tr('male', widget.language), Icons.male_rounded),
                  const SizedBox(width: 8),
                  _buildGenderPill('Female', tr('female', widget.language), Icons.female_rounded),
                  const SizedBox(width: 8),
                  _buildGenderPill('Other', tr('other_gender', widget.language), Icons.transgender_rounded),
                ],
              ),
              // The ABHA number is asked for on its own screen straight after this one.
              // Asking for it twice invites two different answers.
            ],
          );
        }

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
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 40),
                      const SizedBox(height: 8),
                      Text(tr('camera_ready', widget.language), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                        widget.isScanning ? tr('scanning', widget.language) : tr('scan_id', widget.language),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final submitButton = TactileButton(
          onPressed: _hasSomethingToSend ? _submit : null,
          height: 52,
          isSuccess: true,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                '${tr('register_continue', widget.language)} ➔',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        );

        final body = Column(
          children: [
            // Top Title
            if (widget.asking != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_downward_rounded, size: 18, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      '${tr('asking_now', widget.language)}: ${_askingLabel()}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              tr('patient_registration', widget.language),
              style: const TextStyle(
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
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildFormFields(),
                                  const SizedBox(height: 12),
                                  submitButton,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: cameraContent),
                        ],
                      )
                    : (_showScannerOnMobile
                        ? cameraContent
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buildFormFields(),
                                const SizedBox(height: 12),
                                submitButton,
                              ],
                            ),
                          )),
              )
            else
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    buildFormFields(),
                    const SizedBox(height: 12),
                    submitButton,
                  ],
                ),
              ),

            // The wide layout drew this button twice - once under the fields and again at the
            // bottom of the screen. Two identical green buttons is one question too many for
            // someone already unsure whether they have filled the form in correctly.

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
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
