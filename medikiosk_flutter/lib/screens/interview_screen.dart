import 'package:flutter/material.dart';
import '../widgets/body_map_widget.dart';
import '../widgets/faces_severity_widget.dart';
import '../widgets/duration_sun_widget.dart';
import '../widgets/tactile_button.dart';
import '../widgets/vu_meter_widget.dart';

class InterviewScreen extends StatefulWidget {
  final String questionText;
  final String? questionId;
  final String? answerUi;
  final bool isListening;
  final double soundLevel;
  final VoidCallback? onRepeat;
  final String? lastTranscript;
  final bool isProcessing;
  final ValueChanged<String> onSubmitAnswer;
  final VoidCallback? onCompleteIntake;

  const InterviewScreen({
    super.key,
    required this.questionText,
    this.questionId,
    this.answerUi,
    this.isListening = false,
    this.soundLevel = 0,
    this.onRepeat,
    this.lastTranscript,
    this.isProcessing = false,
    required this.onSubmitAnswer,
    this.onCompleteIntake,
  });

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  BodyZone? _selectedZone;
  int? _selectedSeverity;
  String? _selectedDuration;
  bool _showBodyMap = true;
  final _typedAnswer = TextEditingController();

  @override
  void dispose() {
    _typedAnswer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qId = widget.questionId ?? 'ask_complaint';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice Bar & Microphone Status
            VuMeterWidget(
              isListening: widget.isListening,
              isMuted: !widget.isListening,
              audioLevel: widget.soundLevel,
              isProcessing: widget.isProcessing,
            ),
            const SizedBox(height: 10),

            // Question Headline Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF0D9488).withAlpha(80),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.questionText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.onRepeat != null)
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0D9488)),
                      onPressed: widget.onRepeat,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Main Interactive Questionnaire Area
            if (isBounded)
              Expanded(child: _buildQuestionContent(qId, isBounded))
            else
              _buildQuestionContent(qId, isBounded),

            // Universal Typed Input Fallback (supports tests & non-voice patients)
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _typedAnswer,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'लिखकर उत्तर दें (Or type your answer here)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        widget.onSubmitAnswer(val.trim());
                        _typedAnswer.clear();
                      }
                    },
                    onEditingComplete: () {
                      if (_typedAnswer.text.trim().isNotEmpty) {
                        widget.onSubmitAnswer(_typedAnswer.text.trim());
                        _typedAnswer.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  onPressed: () {
                    if (_typedAnswer.text.trim().isNotEmpty) {
                      widget.onSubmitAnswer(_typedAnswer.text.trim());
                      _typedAnswer.clear();
                    }
                  },
                  height: 48,
                  isSuccess: true,
                  borderRadius: BorderRadius.circular(12),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionContent(String qId, bool isBounded) {
    if (qId.contains('severity') || widget.answerUi == 'faces') {
      return FacesSeverityWidget(
        selectedScore: _selectedSeverity,
        onScoreSelected: (score) {
          setState(() => _selectedSeverity = score);
          widget.onSubmitAnswer(score.toString());
        },
      );
    }

    if (qId.contains('duration') || widget.answerUi == 'duration_sun') {
      return DurationSunWidget(
        selectedDuration: _selectedDuration,
        onSelected: (opt) {
          setState(() => _selectedDuration = opt.value);
          widget.onSubmitAnswer(opt.serverValue);
        },
      );
    }

    if (qId.contains('complaint') || widget.answerUi == 'body_map' || qId.contains('location')) {
      final body = _showBodyMap
          ? BodyMapWidget(
              selectedZone: _selectedZone,
              onZoneSelected: (zone) {
                setState(() => _selectedZone = zone);
                final meta = bodyZoneMetadata[zone]!;
                widget.onSubmitAnswer('${meta.labelHi} ${meta.commonComplaint}');
              },
            )
          : LayoutBuilder(
              builder: (context, box) {
                return GridView.count(
                  crossAxisCount: box.maxWidth > 550 ? 2 : 1,
                  childAspectRatio: 3.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    _buildChip('छाती में दर्द (Chest Pain)', 'severe crushing chest pain'),
                    _buildChip('सिर दर्द (Severe Headache)', 'severe throbbing headache'),
                    _buildChip('सांस लेने में तकलीफ (Breathlessness)', 'difficulty breathing shortness of breath'),
                    _buildChip('पेट में तेज दर्द (Stomach Pain)', 'severe acute abdominal stomach pain'),
                    _buildChip('खांसी व जुकाम (Cough & Cold)', 'frequent coughing and running nose'),
                    _buildChip('जोड़ों में दर्द (Joint Pain)', 'knee and joint stiffness pain'),
                  ],
                );
              },
            );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TactileButton(
                onPressed: () => setState(() => _showBodyMap = true),
                isSelected: _showBodyMap,
                height: 40,
                borderRadius: BorderRadius.circular(12),
                child: const Text('शरीर का नक्शा (Body Map)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              TactileButton(
                onPressed: () => setState(() => _showBodyMap = false),
                isSelected: !_showBodyMap,
                height: 40,
                borderRadius: BorderRadius.circular(12),
                child: const Text('लक्षण सूची (Symptom List)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isBounded)
            Expanded(child: body)
          else
            SizedBox(height: 380, child: body),
        ],
      );
    }

    // Default symptom cards
    return LayoutBuilder(
      builder: (context, box) {
        return GridView.count(
          crossAxisCount: box.maxWidth > 550 ? 2 : 1,
          childAspectRatio: 3.5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            _buildChip('हाँ (Yes)', 'yes'),
            _buildChip('नहीं (No)', 'no'),
            _buildChip('पता नहीं (Not Sure)', 'unknown'),
          ],
        );
      },
    );
  }

  Widget _buildChip(String title, String answer) {
    return TactileButton(
      onPressed: () => widget.onSubmitAnswer(answer),
      height: 52,
      borderRadius: BorderRadius.circular(14),
      label: title,
    );
  }
}
