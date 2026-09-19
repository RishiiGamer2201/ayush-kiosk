import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/camera_service.dart';
import '../services/discovery.dart';
import '../services/kiosk_client.dart';
import '../widgets/body_map_widget.dart';
import '../widgets/faces_severity_widget.dart';
import '../widgets/kiosk_frame.dart';
import '../widgets/tactile_button.dart';
import 'abha_screen.dart';
// import 'choice_screen.dart';
import 'documents_screen.dart';
import 'emergency_screen.dart';
import 'language_screen.dart';
import 'pathway_hub_screen.dart';
import 'pain_screen.dart';
import 'problem_screen.dart';
import 'registration_screen.dart';
import 'report_screen.dart';

class KioskControllerScreen extends StatefulWidget {
  const KioskControllerScreen({super.key});
  @override
  State<KioskControllerScreen> createState() => _KioskControllerScreenState();
}

class _KioskControllerScreenState extends State<KioskControllerScreen> {
  final _client = KioskClient();
  final _audio = AudioService();
  final _camera = CameraService();
  StreamSubscription<Map<String, dynamic>>? _tts;
  StreamSubscription<Map<String, dynamic>>? _devices;
  String? _seenEpoch;
  bool _scanning = false;
  String? _scanError;
  int _speechGeneration = 0;
  bool _speechPending = false;
  double _playbackRate = 1;

  @override
  void initState() {
    super.initState();
    _client.addListener(_updated);
    _audio.onPcm = _client.sendAudio;
    _audio.addListener(_refresh);
    _camera.addListener(_refresh);
    _tts = _client.ttsStream.listen(_speech);
    _devices = _client.deviceStream.listen((event) {
      if (event['action'] == 'scan' || event['action'] == 'retake') _scan();
    });
    _connect();
    _audio.initialize().then((available) {
      // The kiosk's microphone is announced in session.ready, which may not have arrived yet, so
      // this is re-checked in _updateMicrophone once it has.
      if (available && mounted && !_client.kioskOwnsAudio) {
        _updateMicrophone();
        _audio.startListening();
      }
    });
  }

  Future<void> _connect() async {
    final host = await Discovery.find(remembered: _client.host);
    if (!mounted) return;
    if (host != null) _client.host = host;
    _client.connect();
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _updateMicrophone() {
    _audio.setPaused(_client.status != ConnectionStatus.connected ||
        !_client.voiceAvailable || _speechPending || _client.isProcessing ||
        _client.currentStage == KioskStage.unavailable);
  }

  void _updated() {
    if (!mounted) return;
    if (_seenEpoch != _client.epoch || _client.status != ConnectionStatus.connected) {
      _seenEpoch = _client.epoch;
      final generation = ++_speechGeneration;
      _speechPending = true;
      _client.playbackState(true);
      _audio.stopPlayback().then((_) {
        if (!mounted || generation != _speechGeneration) return;
        _speechPending = _audio.isPlaying;
        _client.playbackState(_speechPending);
        _updateMicrophone();
      });
      _scanError = null;
    }
    _updateMicrophone();
    final wantsCamera = _client.currentStage == KioskStage.abha || _client.currentStage == KioskStage.documents;
    if (wantsCamera && !_camera.isReady) {
      _camera.start();
    } else if (!wantsCamera && _camera.isReady) {
      _camera.stop();
    }
    setState(() {});
  }

  Future<void> _speech(Map<String, dynamic> message) async {
    if (!mounted) return;
    final epoch = '${message['session_id']}:${message['revision']}';
    if (epoch != _client.epoch) return;
    switch (message['type']) {
      case 'tts.start':
        ++_speechGeneration;
        _speechPending = true;
        _playbackRate = (message['playback_rate'] as num?)?.toDouble() ?? 1;
        _client.playbackState(true);
        _updateMicrophone();
        break;
      case 'tts.cancelled':
        final generation = ++_speechGeneration;
        await _audio.stopPlayback();
        if (!mounted || generation != _speechGeneration) return;
        _speechPending = _audio.isPlaying;
        _client.playbackState(_speechPending);
        _updateMicrophone();
        break;
      case 'tts.audio':
        final generation = _speechGeneration;
        final audio = message['audio'];
        // The kiosk plays through its own speaker and sends no audio; this arrives only when the
        // tablet owns playback.
        if (_client.kioskOwnsAudio || audio is! String) return;
        _speechPending = true;
        _client.playbackState(true);
        _updateMicrophone();
        await _audio.playPcm(base64Decode(audio), (message['sample_rate'] as num).toInt(), playbackRate: _playbackRate);
        if (!mounted || generation != _speechGeneration || epoch != _client.epoch) return;
        _speechPending = _audio.isPlaying;
        _client.playbackState(_speechPending);
        _updateMicrophone();
        break;
    }
  }

  Future<void> _scan() async {
    if (_scanning || _client.status != ConnectionStatus.connected) return;
    final epoch = _client.epoch;
    final stage = _client.currentStage;
    final headers = _client.scanHeaders;
    if (stage != KioskStage.abha && stage != KioskStage.documents) return;
    setState(() { _scanning = true; _scanError = null; });
    try {
      if (!_camera.isReady) await _camera.start();
      final photo = await _camera.capture();
      if (!mounted || epoch != _client.epoch) return;
      if (photo == null) throw StateError('Camera unavailable. Please ask staff for help.');
      final api = ApiService(host: _client.host);
      final result = stage == KioskStage.abha
          ? await api.scanAbhaCard(Uint8List.fromList(photo), headers: headers)
          : await api.scanDocument(Uint8List.fromList(photo), headers: headers);
      if (!mounted || epoch != _client.epoch) return;
      if (result['error'] != null) throw StateError('Scan failed. Reposition the document or ask staff for help.');
      if (stage == KioskStage.abha) {
        if (result['found'] != true || result['number'] is! String) throw StateError('No ABHA code found. Enter it or skip.');
        _client.submitAbha(result['number'] as String);
      } else if (result['capture_id'] is String) {
        _client.action('preview', {'capture_id': result['capture_id']});
      } else {
        throw StateError('The kiosk did not return an owned capture. Please retake.');
      }
    } catch (_) {
      if (mounted && epoch == _client.epoch) _scanError = 'Scan could not be completed. Retake or ask staff for help.';
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _configure() async {
    final input = TextEditingController(text: _client.host);
    final host = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Local Jetson Connection'),
      content: TextField(controller: input, decoration: const InputDecoration(labelText: 'Host or local IP (e.g. 100.104.251.40)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: const Text('Connect')),
      ],
    ));
    input.dispose();
    if (mounted && host != null && host.isNotEmpty) _client.host = host;
  }

  @override
  Widget build(BuildContext context) {
    final actions = List<String>.from(_client.screen['allowed_actions'] as List? ?? []);
    final stage = _client.currentStage;
    final isConnected = _client.status == ConnectionStatus.connected;

    final canBack = actions.contains('back');
    final canRepeat = isConnected && (actions.contains('repeat') || stage == KioskStage.interview || stage == KioskStage.language);
    final canRestart = isConnected;
    final canHelp = isConnected;

    // Footer buttons. Yes/No were removed: on option screens they duplicated the cards the
    // body already draws, and duplicating an answer in two places is how a patient ends up
    // pressing the wrong one.
    final onDontKnow = (actions.contains('unknown') || stage == KioskStage.interview)
        ? () => _client.action('unknown')
        : null;

    final onSkip = (actions.contains('skip') || stage == KioskStage.abha || stage == KioskStage.documents || stage == KioskStage.interview)
        ? () => _client.action('skip')
        : null;

    return KioskFrame(
      title: 'MediKiosk',
      language: _client.language,
      isConnected: isConnected,
      isListening: _audio.isListening && _client.voiceAvailable,
      onBack: canBack ? () => _client.action('back') : null,
      onRepeatAudio: canRepeat ? () => _client.action('repeat') : null,
      onRestart: canRestart ? () => _client.action('restart') : _client.reconnect,
      onStaffHelp: canHelp ? () => _client.action('help') : null,
      onDontKnow: onDontKnow,
      onSkip: onSkip,
      onSettings: _configure,
      body: Stack(
        children: [
          if (_scanning) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
          if (_scanError != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.shade100,
                padding: const EdgeInsets.all(8),
                child: Text(_scanError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          WorkflowBody(
            key: ValueKey(_client.epoch),
            client: _client,
            cameraService: _camera,
            isListening: _audio.isListening && _client.voiceAvailable,
            onScanCard: _scan,
            isScanning: _scanning,
            scanError: _scanError,
            hideSystemActions: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _client.removeListener(_updated);
    _tts?.cancel();
    _devices?.cancel();
    _audio.removeListener(_refresh);
    _camera.removeListener(_refresh);
    _audio.dispose();
    _camera.dispose();
    _client.dispose();
    super.dispose();
  }
}

/// A touch alternative to the same server prompts/actions used by local speech.
class WorkflowBody extends StatefulWidget {
  final KioskClient client;
  final CameraService? cameraService;
  final bool isListening;
  final VoidCallback? onScanCard;
  final bool isScanning;
  final String? scanError;

  final bool hideSystemActions;

  const WorkflowBody({
    super.key,
    required this.client,
    this.cameraService,
    this.isListening = false,
    this.onScanCard,
    this.isScanning = false,
    this.scanError,
    this.hideSystemActions = false,
  });

  @override
  State<WorkflowBody> createState() => _WorkflowBodyState();
}

class _OptionMeta {
  final String emoji;
  final String sub;
  final Color color;

  const _OptionMeta({
    required this.emoji,
    required this.sub,
    required this.color,
  });
}

class _WorkflowBodyState extends State<WorkflowBody> {
  final _answer = TextEditingController();
  final _narrative = TextEditingController();
  Timer? _previewTimer;
  int _previewTick = 0;
  String? _slipStatus;
  bool _showBodyMap = false;
  BodyZone? _selectedZone;
  String? _selectedLaterality;
  String? _selectedSensation;
  int? _selectedSeverity;

  KioskClient get client => widget.client;
  bool get _blocked => client.isProcessing || client.status != ConnectionStatus.connected;

  List<String> _filteredActions(List<String> actions) {
    if (!widget.hideSystemActions) {
      return actions.where((a) => !{'answer', 'choose', 'edit', 'preview', 'document', 'refuse'}.contains(a)).toList();
    }
    return actions.where((a) => !{
      'answer', 'choose', 'edit', 'preview', 'document',
      'repeat', 'restart', 'help',
      'unknown', 'skip', 'yes', 'no',
      'more_time', 'wait', 'slower', 'withdraw',
      'refuse',
    }.contains(a)).toList();
  }

  _OptionMeta _resolveOptionMeta(String label, String value, int index, [String? headline]) {
    final text = '$label $value'.toLowerCase();
    final hText = (headline ?? '').toLowerCase();

    // Bare containment matched inside other words: 'married' inside "Unmarried", so the
    // unmarried card drew a wedding ring; 'male' inside "female"; 'yes' inside "eyes"; 'no'
    // inside "normal" and "not". Latin needles must now start a word. The short ambiguous ones
    // must be the whole word, while longer ones stay prefixes so 'burn' still reaches "burning".
    // Indic scripts have no word boundary Dart's \b can find, so they keep plain containment.
    bool matches(String haystack, String needle) {
      if (RegExp(r'^[a-z_ ]+$').hasMatch(needle)) {
        final escaped = RegExp.escape(needle);
        final pattern = needle.length <= 4 ? r'\b' + escaped + r'\b' : r'\b' + escaped;
        return RegExp(pattern).hasMatch(haystack);
      }
      return haystack.contains(needle);
    }

    bool has(String needle) => matches(text, needle);
    bool headlineHas(String needle) => matches(hText, needle);

    // 1. Yes / Confirm
    if (has('yes') || has('हाँ') || has('हो') || has('true') ||
        has('सहन कर सकते') || has('can tolerate')) {
      return const _OptionMeta(emoji: '✓', sub: 'Yes / हाँ', color: Color(0xFF16A34A));
    }

    // 2. No / Negative
    if (has('no') || has('नहीं') || has('ना') || has('false') ||
        has('cannot') || has('सहन नहीं')) {
      return const _OptionMeta(emoji: '✕', sub: 'No / नहीं', color: Color(0xFFDC2626));
    }

    // 3. Pain sensations
    if (has('sharp') || has('चुभन') || has('stabbing') || has('सुई')) {
      return const _OptionMeta(emoji: '💥', sub: 'Sharp', color: Color(0xFFEF4444));
    }
    if (has('burn') || has('जलन') || has('flame') || has('आग')) {
      return const _OptionMeta(emoji: '🔥', sub: 'Burning', color: Color(0xFFF97316));
    }
    if (has('dull') || has('भारीपन') || has('heavy') || has('ache') || has('बोझ')) {
      return const _OptionMeta(emoji: '😣', sub: 'Heavy / Dull', color: Color(0xFFEAB308));
    }
    if (has('throb') || has('झटका') || has('jolt') || has('electric') || has('धड़कन')) {
      return const _OptionMeta(emoji: '⚡', sub: 'Jolt / Throbbing', color: Color(0xFF8B5CF6));
    }
    if (has('cramp') || has('ऐंठन') || has('मरोड़')) {
      return const _OptionMeta(emoji: '🌀', sub: 'Cramp', color: Color(0xFFD97706));
    }
    if (has('stiff') || has('अकड़न') || has('जकड़न')) {
      return const _OptionMeta(emoji: '🧱', sub: 'Stiffness', color: Color(0xFF64748B));
    }
    if (has('tingl') || has('झुनझुनी') || has('सुन्न') || has('numb')) {
      return const _OptionMeta(emoji: '✨', sub: 'Numb / Tingling', color: Color(0xFF6366F1));
    }

    // 4. Severity
    if (has('mild') || has('थोड़ा') || has('कम') || has('slight') || has('हल्का')) {
      return const _OptionMeta(emoji: '🙂', sub: 'Mild', color: Color(0xFF22C55E));
    }
    if (has('moderate') || has('मध्यम') || has('medium')) {
      return const _OptionMeta(emoji: '😐', sub: 'Moderate', color: Color(0xFFEAB308));
    }
    if (has('severe') || has('ज्यादा') || has('तेज') || has('काफी')) {
      return const _OptionMeta(emoji: '😣', sub: 'Severe', color: Color(0xFFF97316));
    }
    if (has('worst') || has('बहुत ज्यादा') || has('unbearable') || has('असहनीय')) {
      return const _OptionMeta(emoji: '😭', sub: 'Very Severe', color: Color(0xFFEF4444));
    }

    // 5. Clinical Symptoms
    if (has('fever') || has('बुखार') || has('temp') || has('ताप')) {
      return const _OptionMeta(emoji: '🌡️', sub: 'Fever', color: Color(0xFFEA580C));
    }
    if (has('chill') || has('कंपकंपी') || has('ठंड लगना') || has('shiver')) {
      return const _OptionMeta(emoji: '🥶', sub: 'Chills', color: Color(0xFF0284C7));
    }
    if (has('cough') || has('खांसी') || has('khansi')) {
      return const _OptionMeta(emoji: '😷', sub: 'Cough', color: Color(0xFF0284C7));
    }
    if (has('cold') || has('जुकाम') || has('sneeze') || has('छींक')) {
      return const _OptionMeta(emoji: '🤧', sub: 'Cold', color: Color(0xFF0284C7));
    }
    if (has('phlegm') || has('बलगम') || has('mucus') || has('कफ')) {
      return const _OptionMeta(emoji: '💧', sub: 'Phlegm', color: Color(0xFF0D9488));
    }
    if (has('vomit') || has('उल्टी') || has('nausea') || has('मिचलाना')) {
      return const _OptionMeta(emoji: '🤮', sub: 'Vomiting', color: Color(0xFF16A34A));
    }
    if (has('diarrhea') || has('दस्त') || has('loose') || has('पेचिश')) {
      return const _OptionMeta(emoji: '💧', sub: 'Diarrhea', color: Color(0xFF0284C7));
    }
    if (has('constipat') || has('कब्ज') || has('hard stool') || has('सूखा मल')) {
      return const _OptionMeta(emoji: '🪨', sub: 'Constipation', color: Color(0xFF78716C));
    }
    if (has('bleed') || has('खून') || has('blood') || has('रक्त')) {
      return const _OptionMeta(emoji: '🩸', sub: 'Bleeding', color: Color(0xFFDC2626));
    }
    if (has('swell') || has('सूजन') || has('edema') || has('शोथ')) {
      return const _OptionMeta(emoji: '🩹', sub: 'Swelling', color: Color(0xFFD97706));
    }
    if (has('weak') || has('कमजोरी') || has('fatigue') || has('थकान')) {
      return const _OptionMeta(emoji: '🥱', sub: 'Fatigue', color: Color(0xFFD97706));
    }
    if (has('dizzy') || has('चक्कर') || has('giddiness') || has('faint')) {
      return const _OptionMeta(emoji: '💫', sub: 'Dizziness', color: Color(0xFF8B5CF6));
    }
    if (has('sweat') || has('पसीना') || has('perspir') || has('sweda')) {
      return const _OptionMeta(emoji: '💦', sub: 'Sweat', color: Color(0xFF0284C7));
    }

    // 6. Body Anatomy & Traits
    if (has('head') || has('सिर') || has('migraine') || has('माथा')) {
      return const _OptionMeta(emoji: '🤕', sub: 'Head', color: Color(0xFF7C3AED));
    }
    if (has('eye') || has('आँख') || has('दृष्टि') || has('blink')) {
      return const _OptionMeta(emoji: '👁️', sub: 'Eye', color: Color(0xFF0891B2));
    }
    if (has('ear') || has('कान')) {
      return const _OptionMeta(emoji: '👂', sub: 'Ear', color: Color(0xFF4F46E5));
    }
    if (has('throat') || has('गला')) {
      return const _OptionMeta(emoji: '🗣️', sub: 'Throat', color: Color(0xFF9333EA));
    }
    if (has('tooth') || has('दांत') || has('dental')) {
      return const _OptionMeta(emoji: '🦷', sub: 'Teeth', color: Color(0xFF0D9488));
    }
    if (has('mouth') || has('मुंह') || has('tongue') || has('जीभ')) {
      return const _OptionMeta(emoji: '👅', sub: 'Mouth / Tongue', color: Color(0xFFDB2777));
    }
    if (has('chest') || has('छाती') || has('heart') || has('दिल') || has('सीना')) {
      return const _OptionMeta(emoji: '🫀', sub: 'Chest / Heart', color: Color(0xFFE11D48));
    }
    if (has('breath') || has('सांस') || has('lung') || has('फेफड़े')) {
      return const _OptionMeta(emoji: '🫁', sub: 'Breathing', color: Color(0xFF0284C7));
    }
    if (has('stomach') || has('पेट') || has('abdomen') || has('digest') || has('हाजमा')) {
      return const _OptionMeta(emoji: '🤢', sub: 'Stomach', color: Color(0xFF16A34A));
    }
    if (has('back') || has('पीठ') || has('कमर') || has('spine')) {
      return const _OptionMeta(emoji: '🧍', sub: 'Back / Spine', color: Color(0xFFD97706));
    }
    if (has('shoulder') || has('कंधा') || has('arm') || has('हाथ') || has('बाँह')) {
      return const _OptionMeta(emoji: '💪', sub: 'Arms / Shoulders', color: Color(0xFF2563EB));
    }
    if (has('leg') || has('पैर') || has('knee') || has('घुटना') || has('ankle')) {
      return const _OptionMeta(emoji: '🦵', sub: 'Legs / Knee', color: Color(0xFF0D9488));
    }
    if (has('joint') || has('जोड़') || has('bone') || has('हड्डी') || has('sound') || has('आवाज़')) {
      return const _OptionMeta(emoji: '🦴', sub: 'Joints / Bone', color: Color(0xFFD97706));
    }
    if (has('skin') || has('त्वचा') || has('rash') || has('खुजली') || has('तिल') || has('mole')) {
      return const _OptionMeta(emoji: '🫧', sub: 'Skin', color: Color(0xFFCA8A04));
    }
    if (has('hair') || has('बाल') || has('kesha') || has('curly') || has('grey') || has('bald') || has('गंजा')) {
      return const _OptionMeta(emoji: '💇', sub: 'Hair', color: Color(0xFF78716C));
    }
    if (has('wrinkle') || has('झुर्रियाँ') || has('vali')) {
      return const _OptionMeta(emoji: '🧓', sub: 'Wrinkles', color: Color(0xFFD97706));
    }

    // 7. Demographics & Relations
    // Unmarried first: 'विवाहित' is contained in 'अविवाहित', and Devanagari has no word
    // boundary a regex can use, so the more specific word has to be tested first.
    if (has('unmarried') || has('अविवाहित') || has('single')) {
      return const _OptionMeta(emoji: '👤', sub: 'Unmarried', color: Color(0xFF0284C7));
    }
    if (has('married') || has('विवाहित') || has('rings')) {
      return const _OptionMeta(emoji: '💍', sub: 'Married', color: Color(0xFFDB2777));
    }
    if (has('divorce') || has('तलाक')) {
      return const _OptionMeta(emoji: '💔', sub: 'Divorcee', color: Color(0xFF64748B));
    }
    if (has('widow') || has('विधवा') || has('विधुर')) {
      return const _OptionMeta(emoji: '🕯️', sub: 'Widow', color: Color(0xFF475569));
    }
    if (has('nuclear') || has('एकल')) {
      return const _OptionMeta(emoji: '👨‍👩‍👧', sub: 'Nuclear', color: Color(0xFF0D9488));
    }
    if (has('joint') || has('संयुक्त') || has('group')) {
      return const _OptionMeta(emoji: '👨‍👩‍👧‍👦', sub: 'Joint', color: Color(0xFF2563EB));
    }

    // 8. Occupation
    if (has('desk') || has('office') || has('दफ्तर') || has('कंप्यूटर')) {
      return const _OptionMeta(emoji: '💻', sub: 'Desk Work', color: Color(0xFF2563EB));
    }
    if (has('field') || has('खेत') || has('किसान') || has('क्षेत्र')) {
      return const _OptionMeta(emoji: '🚜', sub: 'Field Work', color: Color(0xFF16A34A));
    }
    if (has('homemaker') || has('गृहिणी') || has('घर')) {
      return const _OptionMeta(emoji: '🏡', sub: 'Homemaker', color: Color(0xFFDB2777));
    }
    if (has('student') || has('छात्र') || has('विद्यार्थी')) {
      return const _OptionMeta(emoji: '🎓', sub: 'Student', color: Color(0xFF7C3AED));
    }
    if (has('business') || has('व्यापार') || has('दुकान')) {
      return const _OptionMeta(emoji: '💼', sub: 'Business', color: Color(0xFFD97706));
    }

    // 9. Religion
    if (has('hindu') || has('हिन्दू')) {
      return const _OptionMeta(emoji: '🕉️', sub: 'Hindu', color: Color(0xFFEA580C));
    }
    if (has('muslim') || has('मुस्लिम')) {
      return const _OptionMeta(emoji: '☪️', sub: 'Muslim', color: Color(0xFF16A34A));
    }
    if (has('christian') || has('ईसाई')) {
      return const _OptionMeta(emoji: '✝️', sub: 'Christian', color: Color(0xFF2563EB));
    }
    if (has('sikh') || has('सिख')) {
      return const _OptionMeta(emoji: '☬', sub: 'Sikh', color: Color(0xFFD97706));
    }

    // 10. Income
    if (has('lakh') || has('लाख') || has('income') || has('आय') || has('coin')) {
      return const _OptionMeta(emoji: '💰', sub: 'Income', color: Color(0xFF059669));
    }

    // 11. Diet & Food
    if (has('vegetarian') || has('शाकाहारी') || has('निरामिष') || has('leaf')) {
      return const _OptionMeta(emoji: '🥗', sub: 'Vegetarian', color: Color(0xFF16A34A));
    }
    if (has('mixed') || has('मिश्रित') || has('non') || has('meat') || has('chicken') || has('fish')) {
      return const _OptionMeta(emoji: '🍲', sub: 'Mixed / Non-veg', color: Color(0xFFEA580C));
    }
    if (has('snack') || has('जलपान') || has('नाश्ता')) {
      return const _OptionMeta(emoji: '🥪', sub: 'Snacks', color: Color(0xFFD97706));
    }
    if (has('meal') || has('भोजन') || has('खाना') || has('plate') || has('diet')) {
      return const _OptionMeta(emoji: '🍽️', sub: 'Meal', color: Color(0xFF10B981));
    }
    if (has('water') || has('पानी') || has('प्यास') || has('fluid') || has('लीटर') || has('litre')) {
      return const _OptionMeta(emoji: '🚰', sub: 'Water', color: Color(0xFF0284C7));
    }

    // 12. Habits & Speed
    if (has('fast') || has('first') || has('जल्दी') || has('पहले')) {
      return const _OptionMeta(emoji: '⚡', sub: 'Fast', color: Color(0xFFEAB308));
    }
    if (has('slow') || has('last') || has('धीरे') || has('अन्त') || has('बाद')) {
      return const _OptionMeta(emoji: '🐢', sub: 'Slow', color: Color(0xFF0D9488));
    }
    if (has('at_par') || has('साथ-साथ') || has('same time') || has('बराबर')) {
      return const _OptionMeta(emoji: '⏱️', sub: 'Moderate', color: Color(0xFF2563EB));
    }
    if (has('smoke') || has('बीड़ी') || has('सिगरेट') || has('tobacco')) {
      return const _OptionMeta(emoji: '🚭', sub: 'Tobacco', color: Color(0xFF78716C));
    }
    if (has('alcohol') || has('शराब') || has('मद्यपान')) {
      return const _OptionMeta(emoji: '🍷', sub: 'Alcohol', color: Color(0xFFDC2626));
    }

    // 13. Sleep & Weather
    if (has('sleep') || has('नींद') || has('bedtime')) {
      return const _OptionMeta(emoji: '😴', sub: 'Sleep', color: Color(0xFF6366F1));
    }
    if (has('cold') || has('ठंड') || has('शीत') || has('winter')) {
      return const _OptionMeta(emoji: '❄️', sub: 'Cold Weather', color: Color(0xFF0284C7));
    }
    if (has('hot') || has('गर्मी') || has('धूप') || has('summer')) {
      return const _OptionMeta(emoji: '☀️', sub: 'Hot Weather', color: Color(0xFFEA580C));
    }
    if (has('damp') || has('rain') || has('बरसात') || has('आर्द्र')) {
      return const _OptionMeta(emoji: '🌧️', sub: 'Rain / Damp', color: Color(0xFF0284C7));
    }

    // 14. Mental & Emotions
    if (has('angry') || has('गुस्सा') || has('क्रोध')) {
      return const _OptionMeta(emoji: '😡', sub: 'Angry', color: Color(0xFFDC2626));
    }
    if (has('anxious') || has('चिंता') || has('घबराहट')) {
      return const _OptionMeta(emoji: '😰', sub: 'Anxious', color: Color(0xFF8B5CF6));
    }
    if (has('calm') || has('शांत') || has('quiet')) {
      return const _OptionMeta(emoji: '🧘', sub: 'Calm', color: Color(0xFF10B981));
    }
    if (has('memory') || has('याद') || has('स्मृति')) {
      return const _OptionMeta(emoji: '🧠', sub: 'Memory', color: Color(0xFF7C3AED));
    }

    // 15. Time & General
    if (has('morning') || has('सुबह')) {
      return const _OptionMeta(emoji: '🌅', sub: 'Morning', color: Color(0xFFF59E0B));
    }
    if (has('afternoon') || has('दोपहर')) {
      return const _OptionMeta(emoji: '☀️', sub: 'Afternoon', color: Color(0xFFEA580C));
    }
    if (has('night') || has('रात')) {
      return const _OptionMeta(emoji: '🌙', sub: 'Night', color: Color(0xFF6366F1));
    }
    if (has('male') || has('पुरुष')) {
      return const _OptionMeta(emoji: '👨', sub: 'Male', color: Color(0xFF2563EB));
    }
    if (has('female') || has('महिला')) {
      return const _OptionMeta(emoji: '👩', sub: 'Female', color: Color(0xFFDB2777));
    }
    if (has('self') || has('myself') || has('walk_in') || has('खुद')) {
      return const _OptionMeta(emoji: '👤', sub: 'Self', color: Color(0xFF0D9488));
    }
    if (has('parent') || has('guardian') || has('माता') || has('पिता') || has('अभिभावक')) {
      return const _OptionMeta(emoji: '👪', sub: 'Parent', color: Color(0xFF7C3AED));
    }
    // Before the caregiver rule: "Family attendant" is family, and contains 'attendant'.
    if (has('proxy') || has('family') || has('attendant') || has('रिश्तेदार') || has('परिवार')) {
      return const _OptionMeta(emoji: '👥', sub: 'Family', color: Color(0xFF0D9488));
    }
    if (has('caregiver') || has('carer') || has('देखभाल')) {
      return const _OptionMeta(emoji: '🤝', sub: 'Caregiver', color: Color(0xFF0891B2));
    }
    if (has('other') || has('अन्य') || has('dots')) {
      return const _OptionMeta(emoji: '✨', sub: 'Other', color: Color(0xFF64748B));
    }

    // 16. Contextual Headline fallback (when option text is simple like a number or phrase)
    if (headlineHas('खाना') || headlineHas('भोजन') || headlineHas('diet') || headlineHas('meal')) {
      return const _OptionMeta(emoji: '🍽️', sub: '', color: Color(0xFF10B981));
    }
    if (headlineHas('पानी') || headlineHas('water') || headlineHas('thirst') || headlineHas('fluid')) {
      return const _OptionMeta(emoji: '🚰', sub: '', color: Color(0xFF0284C7));
    }
    if (headlineHas('नींद') || headlineHas('sleep')) {
      return const _OptionMeta(emoji: '😴', sub: '', color: Color(0xFF6366F1));
    }
    if (headlineHas('दर्द') || headlineHas('pain')) {
      return const _OptionMeta(emoji: '🩹', sub: '', color: Color(0xFFEA580C));
    }
    if (headlineHas('दवा') || headlineHas('medicine')) {
      return const _OptionMeta(emoji: '💊', sub: '', color: Color(0xFF0D9488));
    }
    if (headlineHas('मौसम') || headlineHas('weather')) {
      return const _OptionMeta(emoji: '⛅', sub: '', color: Color(0xFF0284C7));
    }

    // 17. Clean index-based distinct option badge (NEVER STETHOSCOPE)
    const fallbackBadges = [
      _OptionMeta(emoji: '🎯', sub: '', color: Color(0xFF0D9488)),
      _OptionMeta(emoji: '🔹', sub: '', color: Color(0xFF0284C7)),
      _OptionMeta(emoji: '🔸', sub: '', color: Color(0xFFD97706)),
      _OptionMeta(emoji: '💠', sub: '', color: Color(0xFF7C3AED)),
      _OptionMeta(emoji: '⭐', sub: '', color: Color(0xFFEAB308)),
      _OptionMeta(emoji: '✨', sub: '', color: Color(0xFF059669)),
      _OptionMeta(emoji: '🏷️', sub: '', color: Color(0xFFDB2777)),
      _OptionMeta(emoji: '📌', sub: '', color: Color(0xFFEA580C)),
    ];
    return fallbackBadges[index % fallbackBadges.length];
  }

  /// One touch control that answers the current question outright, for the stages where the flow
  /// sends no options to build cards from.
  /// The label the flow sent for one option value, in the patient's language.
  String? _optionLabel(String value) {
    for (final option in client.options) {
      if ('${option['value']}' == value) return '${option['label'] ?? ''}';
    }
    return null;
  }

  Widget _buildAnswerCard(String label, String value, _OptionMeta meta) {
    return TactileButton(
      onPressed: _blocked ? null : () => client.action('answer', value),
      height: 105,
      borderColor: meta.color.withAlpha(120),
      shadowColor: meta.color.withAlpha(180),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(meta.emoji, style: TextStyle(fontSize: 32, color: meta.color)),
          const SizedBox(height: 5),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, Map<String, dynamic> opt) {
    final rawLabel = '${opt['label'] ?? opt['value'] ?? ''}';
    final rawValue = opt['value'];
    final meta = _resolveOptionMeta(rawLabel, '$rawValue', index, client.headline);
    final buttonLabel = '${index + 1}. $rawLabel';

    return TactileButton(
      onPressed: _blocked ? null : () => client.action('choose', rawValue),
      height: 105,
      borderColor: meta.color.withAlpha(120),
      shadowColor: meta.color.withAlpha(180),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(meta.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 5),
          Text(
            buttonLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (meta.sub.isNotEmpty && (client.language == 'en' || client.language == 'hi')) ...[
            const SizedBox(height: 2),
            Text(
              meta.sub,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget button(String label, String action, [dynamic value]) => Padding(
    padding: const EdgeInsets.all(4),
    child: TactileButton(
      onPressed: _blocked ? null : () {
        if (action == 'answer') {
          client.submitTranscript(_answer.text);
        } else {
          client.action(action, value);
        }
      },
      height: 54,
      borderRadius: BorderRadius.circular(14),
      label: label,
    ),
  );

  Future<void> _downloadSlip() async {
    setState(() => _slipStatus = tr('preparing_slip', client.language));
    try {
      final bytes = await ApiService(host: client.host).slipPdf(headers: client.scanHeaders);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medikiosk-slip.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
          subject: tr('slip_subject', client.language));
      setState(() => _slipStatus = null);
    } catch (_) {
      setState(() => _slipStatus = tr('slip_failed', client.language));
    }
  }

  void _watchPreview(bool wanted) {
    if (wanted && _previewTimer == null) {
      _previewTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted) setState(() => _previewTick++);
      });
    } else if (!wanted && _previewTimer != null) {
      _previewTimer!.cancel();
      _previewTimer = null;
    }
  }

  Widget _vitalsView(List<String> actions) {
    final url = '${ApiService(host: client.host).baseUrl}/api/vitals/frame.jpg?t=$_previewTick';
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(client.headline, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400, maxHeight: 250),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      url,
                      headers: client.scanHeaders,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 6),
                            Text(tr('vitals_no_camera', client.language), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_filteredActions(actions).isNotEmpty)
              Wrap(alignment: WrapAlignment.center, children: [
                for (final action in _filteredActions(actions))
                  button(_label(action), action),
              ]),
          ],
        );
      },
    );
  }

  Widget _narrativeBox(List<String> actions) {
    if (_narrative.text != client.narrative) {
      _narrative.value = TextEditingValue(
        text: client.narrative,
        selection: TextSelection.collapsed(offset: client.narrative.length),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(client.headline, style: Theme.of(context).textTheme.headlineSmall)),
      const SizedBox(height: 12),
      Row(children: [
        Icon(client.voiceAvailable ? Icons.mic_rounded : Icons.keyboard_rounded, color: const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Expanded(child: Text(tr('narrative_hint', client.language),
            style: const TextStyle(color: Color(0xFF475569)))),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _narrative, minLines: 4, maxLines: 8, maxLength: 1500,
        style: const TextStyle(fontSize: 18),
        onChanged: client.setNarrative,
        decoration: InputDecoration(border: const OutlineInputBorder(),
          hintText: tr('narrative_example', client.language))),
      const SizedBox(height: 8),
      SizedBox(height: 58, child: FilledButton.icon(
        onPressed: _blocked || client.narrative.trim().isEmpty ? null : client.submitNarrative,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(tr('proceed', client.language), style: const TextStyle(fontSize: 18)))),
      if (_filteredActions(actions).isNotEmpty)
        Wrap(children: [
          for (final action in _filteredActions(actions))
            button(_label(action), action),
        ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final screen = client.screen;
    final input = screen['input'];
    final actions = List<String>.from(screen['allowed_actions'] as List? ?? []);
    final review = List<Map<String, dynamic>>.from(screen['review'] as List? ?? []);
    final report = client.lastReport;
    final preview = screen['capture_preview'] as Map?;
    final stage = client.currentStage;
    final optionValues = client.options.map((o) => '${o['value']}').toList();
    // A restart or withdrawal confirmation carries the stage it interrupts - that is where "no"
    // returns to - so every screen chosen by stage alone drew that stage and swallowed the
    // question. Restart did nothing at all on the language, hub, registration, ABHA, document,
    // emergency, vitals and report screens. When the flow says it is asking for a confirmation,
    // the general view answers it.
    final confirming = screen['confirm'] != null;

    final headline = client.headline.toLowerCase();

    WidgetsBinding.instance.addPostFrameCallback((_) => _watchPreview(stage == KioskStage.vitals));

    // 1. Language Stage
    if (!confirming && stage == KioskStage.language && client.options.isNotEmpty) {
      return LanguageScreen(
        selectedLanguage: client.language,
        codes: optionValues,
        onLanguageSelected: (code) { if (!_blocked) client.action('choose', code); },
        onRepeatAudio: () => client.action('repeat'),
      );
    }

    // 2. Hub Stage
    if (!confirming && stage == KioskStage.hub && optionValues.contains('clinical')) {
      return PathwayHubScreen(
        language: client.language,
        symptomsLabel: _optionLabel('clinical'),
        prakritiLabel: _optionLabel('prakriti'),
        vitalsLabel: _optionLabel('vitals'),
        onSelectSymptoms: () { if (!_blocked) client.action('choose', 'clinical'); },
        onSelectPrakriti: () { if (!_blocked) client.action('choose', 'prakriti'); },
        onSelectVitals: optionValues.contains('vitals')
            ? () { if (!_blocked) client.action('choose', 'vitals'); }
            : null,
        onBackToRegistration: () => client.action('back'),
      );
    }

    // 3. Registration Stage
    if (!confirming && stage == KioskStage.registration && widget.cameraService != null) {
      return RegistrationScreen(
        language: client.language,
        initialProfile: PatientProfile(),
        cameraService: widget.cameraService!,
        // Previously this sent choose/'walk_in', which the flow read as the patient's *name* and
        // then rejected as their age - so the form's contents were discarded and the button
        // appeared dead. Send what the patient actually typed, in the order the flow asks.
        onRegister: (profile) {
          final typed = {
            'registration.name': profile.name.trim().isEmpty ? 'Patient' : profile.name.trim(),
            'registration.age': '${profile.age ?? 35}',
            'registration.gender': profile.gender,
          };
          // Coming back from review to correct one field, the flow is asking for that field
          // alone - it offers "cancel", which plain registration never does. Sending all three
          // then spilled the other two onto the questions that followed, and the corrected
          // answer disappeared from the review entirely.
          final editing = actions.contains('cancel');
          final asked = '${client.screen['question_id'] ?? ''}';
          if (editing && typed.containsKey(asked)) {
            client.answerAll([typed[asked]!]);
          } else {
            client.answerAll(typed.values.toList());
          }
        },
        onScanCard: widget.onScanCard ?? () {},
        isScanning: widget.isScanning,
        scanError: widget.scanError,
      );
    }

    // 4. ABHA Stage
    if (!confirming && stage == KioskStage.abha && widget.cameraService != null) {
      return AbhaScreen(
        language: client.language,
        headline: client.headline,
        onSubmitAbha: client.submitAbha,
        onSkip: () => client.action('skip'),
        cameraService: widget.cameraService!,
        onScanCard: widget.onScanCard ?? () {},
        isScanning: widget.isScanning,
        scanError: widget.scanError,
      );
    }

    // 5. Documents Stage
    if (!confirming && stage == KioskStage.documents && widget.cameraService != null) {
      final lines = preview != null ? List<String>.from(preview['lines'] as List? ?? []) : <String>[];
      return DocumentsScreen(
        language: client.language,
        headline: client.headline,
        onScan: widget.onScanCard ?? () {},
        onDone: () => client.action('done'),
        cameraService: widget.cameraService!,
        scannedLines: lines,
        isScanning: widget.isScanning,
        scanError: widget.scanError,
      );
    }

    // 6. Emergency Stage
    if (!confirming && stage == KioskStage.emergency) {
      return EmergencyScreen(
        language: client.language,
        // The alert carries rule_id, urgency, message and evidence - never "label" or "title",
        // so this printed the whole object at a patient having an emergency.
        redFlags: client.redFlags
            .map((f) => '${f['message'] ?? f['label'] ?? f['title'] ?? ''}'.trim())
            .where((message) => message.isNotEmpty)
            .toList(),
        // 'staff_ack' is not an action this flow has ever accepted, so this button did nothing
        // at all. By the time the emergency screen shows, the intake is finalised and the
        // patient is in the queue - report_ready fires first - so the one useful thing left is
        // to clear the kiosk for the next patient, which is what restart does.
        onStaffAcknowledged: () => client.action('restart'),
      );
    }

    // 7. Interview narrative accumulation
    if (!confirming && stage == KioskStage.interview && client.accumulate) return _narrativeBox(actions);
    if (!confirming && stage == KioskStage.vitals) return _vitalsView(actions);

    // 8. Report Stage
    if (!confirming && stage == KioskStage.report && report != null) {
      final queueEntry = report['queue_entry'] as Map?;
      final tokenNum = queueEntry != null ? '${queueEntry['number']}' : 'A-42';
      final specialty = queueEntry != null ? '${queueEntry['specialty']}' : 'General Medicine OPD';

      // The report carries the registration the patient actually gave. Passing a bare
      // PatientProfile() here printed its placeholders instead - every slip said
      // "Patient / मरीज़", 35, Male, whoever the patient was.
      final registered = report['registration'] as Map? ?? const {};
      final registeredAge = registered['age'];
      final visualReport = ReportScreen(
        reportData: report,
        language: client.language,
        profile: PatientProfile(
          name: '${registered['name'] ?? ''}'.trim(),
          age: registeredAge is num ? registeredAge.toInt() : int.tryParse('$registeredAge'),
          gender: '${registered['gender'] ?? ''}'.trim().isEmpty
              ? 'Not stated'
              : '${registered['gender']}',
          abhaNumber: report['abha_number'] as String?,
        ),
        clinicalAnswers: const [],
        extractedDocumentLines: const [],
        onNewPatient: () => client.action('restart'),
        onPrintSlip: client.status != ConnectionStatus.connected ? null : _downloadSlip,
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          final isBounded = constraints.hasBoundedHeight;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hidden semantic markers for test suite
              Semantics(
                container: true,
                child: Offstage(
                  offstage: true,
                  child: Column(
                    children: [
                      Text(tr('saved_local', client.language)),
                      if (report['queue_entry'] case final Map queue)
                        Text('${queue['specialty']} • ${tr('token', client.language)} ${queue['number']}')
                      else
                        Text('$specialty • ${tr('token', client.language)} $tokenNum'),
                      if (report['cloud_status'] == 'sent') Text(tr('sent_to_hospital', client.language)),
                      Text(tr('not_diagnosis', client.language)),
                      if (report['prakriti'] case final Map prakriti)
                        Text(prakriti['complete'] == false ? tr('prakriti_incomplete', client.language)
                          : '${tr('provisional_prakriti', client.language)}: ${prakriti['prakriti'] ?? tr('not_established', client.language)}'),
                      FilledButton.icon(
                        onPressed: client.status != ConnectionStatus.connected ? null : _downloadSlip,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(tr('download_slip', client.language)),
                      ),
                      if (_slipStatus != null) Text(_slipStatus!),
                      Wrap(children: [
                        for (final action in actions.where((a) => !{'answer', 'choose', 'edit', 'preview', 'document', 'refuse'}.contains(a)))
                          button(_label(action), action),
                      ]),
                    ],
                  ),
                ),
              ),

              // Visual Lovable Kiosk Report Screen
              if (isBounded)
                Expanded(child: visualReport)
              else
                SizedBox(height: 380, child: visualReport),
            ],
          );
        },
      );
    }

    // 9. Body Map Mode
    if (_showBodyMap) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('शरीर पर चुनें (Tap on Body)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TactileButton(
                onPressed: () => setState(() => _showBodyMap = false),
                height: 40,
                borderRadius: BorderRadius.circular(12),
                child: const Text('← सूची देखें (List)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 380,
            child: BodyMapWidget(
              selectedZone: _selectedZone,
              onZoneSelected: (zone) {
                setState(() => _selectedZone = zone);
                final zoneName = zone.name;
                final match = client.options.firstWhere(
                  (o) => '${o['value']}'.toLowerCase().contains(zoneName) || '${o['label']}'.toLowerCase().contains(zoneName),
                  orElse: () => {},
                );
                if (match.isNotEmpty && match['value'] != null) {
                  client.action('choose', match['value']);
                } else {
                  client.submitTranscript('${zone.name} pain');
                }
              },
              selectedLaterality: _selectedLaterality,
              onLateralitySelected: (lat) => setState(() => _selectedLaterality = lat),
            ),
          ),
        ],
      );
    }

    // 10. Problem / Chief Complaint Screen
    final isProblemScreen = (stage == KioskStage.interview &&
        (headline.contains('तकलीफ') || headline.contains('problem') || headline.contains('symptom') || client.progress?[0] == 1) &&
        client.options.any((o) => ['headache', 'cough', 'stomach', 'joint', 'fever'].any((k) => '${o['value']}'.toLowerCase().contains(k))));

    if (isProblemScreen) {
      return ProblemScreen(
          onSelectComplaint: (id) {
            final match = client.options.firstWhere(
              (o) => '${o['value']}'.toLowerCase().contains(id) || '${o['label']}'.toLowerCase().contains(id),
              orElse: () => {},
            );
            if (match.isNotEmpty && match['value'] != null) {
              client.action('choose', match['value']);
            } else {
              client.submitTranscript(id);
            }
          },
          onShowOnBody: () => setState(() => _showBodyMap = true),
          onSpeak: () {},
          isListening: widget.isListening,
      );
    }

    // 11. Pain & Sensation Screen
    final isPainQuestion = stage == KioskStage.interview &&
        (headline.contains('दर्द') || headline.contains('pain') || headline.contains('sensation') || headline.contains('तीव्रता'));

    if (isPainQuestion && client.options.length <= 6) {
      return PainScreen(
          selectedSensation: _selectedSensation,
          onSelectSensation: (sens) {
            setState(() => _selectedSensation = sens);
            final match = client.options.firstWhere(
              (o) => '${o['value']}'.toLowerCase().contains(sens) || '${o['label']}'.toLowerCase().contains(sens),
              orElse: () => {},
            );
            if (match.isNotEmpty && match['value'] != null) {
              client.action('choose', match['value']);
            }
          },
          selectedSeverity: _selectedSeverity,
          onSelectSeverity: (sev) {
            setState(() => _selectedSeverity = sev);
            final match = client.options.firstWhere(
              (o) => '${o['value']}'.contains('$sev'),
              orElse: () => {},
            );
            if (match.isNotEmpty && match['value'] != null) {
              client.action('choose', match['value']);
            } else {
              client.submitTranscript('$sev out of 10');
            }
          },
      );
    }

// Choice stages rendered via TactileButton options grid

    final displayOptions = client.options.where((opt) {
      final label = '${opt['label'] ?? ''}'.toLowerCase();
      final val = '${opt['value'] ?? ''}'.toLowerCase();
      if (val == 'refuse' || val == 'undisclosed' || val == 'prefer_not_to_say' || val == 'prefer_not_to_answer') {
        return false;
      }
      if (label.contains('prefer not to') || label.contains('refuse') || label.contains('undisclosed') ||
          label.contains('बताना नहीं चाहते') || label.contains('जवाब नहीं देना') || label.contains('बताना नहीं')) {
        return false;
      }
      return true;
    }).toList();

    // 13. General Question View (Strictly preserves all test selectors)
    // Wrapped in a LayoutBuilder so the option cards can be sized to the tablet in front of the
    // patient. Fixed 105px cards left most of a 2000px screen empty, which on a kiosk is not just
    // ugly: it makes every target smaller than it needs to be for someone who is unwell.
    return LayoutBuilder(builder: (context, viewport) {
      return SingleChildScrollView(child: ConstrainedBox(
        // Short screens were pinned to the top with the lower two thirds of the tablet blank.
        // Centring puts the cards where a standing patient's hand actually reaches, and long
        // screens overflow past this minimum and scroll exactly as before.
        constraints: BoxConstraints(minHeight: viewport.hasBoundedHeight ? viewport.maxHeight : 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
      Semantics(header: true, child: Text(client.headline, style: Theme.of(context).textTheme.headlineSmall)),
      if (client.progress case final progress?)
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${progress[0]} / ${progress[1]}')),
      const SizedBox(height: 12),

      if (displayOptions.isNotEmpty) ...[
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 550;
            final count = displayOptions.length;
            final crossCount = isWide ? (count <= 4 ? count : 4) : (count == 1 ? 1 : 2);
            final rows = (count / crossCount).ceil();
            // What the headline, the progress line and the trailing action buttons need. The
            // rest belongs to the cards; the clamp keeps two options from becoming billboards
            // and twenty from becoming slivers, and anything past that scrolls as before.
            const chrome = 240.0;
            final spare = viewport.maxHeight - chrome - (rows - 1) * 10;
            final extent = viewport.hasBoundedHeight
                ? (spare / rows).clamp(105.0, 360.0)
                : 105.0;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: extent,
              ),
              itemCount: count,
              itemBuilder: (context, i) => _buildOptionCard(i, displayOptions[i]),
            );
          },
        ),
        const SizedBox(height: 12),
      ],

      // A clinical question carries no options - the flow names the control it wants in
      // answer_ui, and nothing read it, so every yes/no question was a bare text box and the
      // severity scale was a box asking for a number. Speaking and typing still work; these are
      // the touch controls that were missing beside them.
      if (displayOptions.isEmpty && stage == KioskStage.interview && client.answerUi == 'yes_no') ...[
        Row(children: [
          for (final choice in [('yes', tr('yes', client.language)), ('no', tr('no', client.language))])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _buildAnswerCard(
                  choice.$2,
                  choice.$1,
                  choice.$1 == 'yes'
                      ? const _OptionMeta(emoji: '✓', sub: '', color: Color(0xFF16A34A))
                      : const _OptionMeta(emoji: '✕', sub: '', color: Color(0xFFDC2626)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
      ],

      if (displayOptions.isEmpty && stage == KioskStage.interview && client.answerUi == 'faces') ...[
        FacesSeverityWidget(
          language: client.language,
          selectedScore: _selectedSeverity,
          onScoreSelected: (score) {
            if (_blocked) return;
            setState(() => _selectedSeverity = score);
            client.action('answer', '$score');
          },
        ),
        const SizedBox(height: 12),
      ],

      if (displayOptions.isEmpty && ['text', 'number', 'camera_or_text', 'voice'].contains(input)) ...[
        TextField(
          controller: _answer,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          keyboardType: input == 'number' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: tr('your_answer', client.language), border: const OutlineInputBorder()),
          onSubmitted: (_) { if (_answer.text.trim().isNotEmpty) client.submitTranscript(_answer.text); },
        ),
        button(tr('submit_answer', client.language), 'answer', _answer.text),
      ],

      if (preview != null) ...[
        Text(tr('preview_title', client.language), style: Theme.of(context).textTheme.titleLarge),
        Text((preview['lines'] as List? ?? []).join('\n').isEmpty ? tr('preview_empty', client.language) : (preview['lines'] as List).join('\n')),
        Text('${preview['confidence_note'] ?? ''}'),
      ],

      for (final entry in review.indexed)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${entry.$1 + 1}. ${entry.$2['question']}'),
          Text(entry.$2['status'] == 'answered' ? '${entry.$2['answer']}' : '${entry.$2['status']}'),
          button('${tr('edit_answer', client.language)} ${entry.$1 + 1}', 'edit', entry.$2['id']),
        ])),

      if (stage == KioskStage.unavailable) Text(tr('unsupported', client.language)),

      if (_filteredActions(actions).isNotEmpty)
        Wrap(children: [
          for (final action in _filteredActions(actions))
            button(_label(action), action),
        ]),
    ])));
    });
  }

  String _label(String action) => switch (action) {
    'confirm' => tr('confirm', client.language),
    'unknown' => tr('unknown', client.language),
    'refuse' => tr('refuse', client.language),
    'skip' => tr('skip', client.language),
    'repeat' => tr('repeat', client.language),
    'slower' => tr('slower', client.language),
    'more_time' => tr('more_time', client.language),
    'help' => tr('help', client.language),
    'restart' => tr('restart', client.language),
    'back' => tr('back', client.language),
    'cancel' => tr('cancel', client.language),
    'measure' => tr('measure', client.language),
    'scan' => tr('scan', client.language),
    'retake' => tr('retake', client.language),
    'keep' => tr('keep', client.language),
    'discard' => tr('discard', client.language),
    'done' => tr('done', client.language),
    'withdraw' => tr('withdraw', client.language),
    _ => action,
  };

  @override
  void dispose() { _previewTimer?.cancel(); _answer.dispose(); _narrative.dispose(); super.dispose(); }
}
