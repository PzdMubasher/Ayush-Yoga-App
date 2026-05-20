import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../utils/pose_painter.dart';
import '../models/yoga_pose.dart';
import '../providers/language_provider.dart';

class CameraScreen extends StatefulWidget {
  final YogaPose pose;
  final int durationMins;
  final String level;
  const CameraScreen({super.key, required this.pose, this.durationMins = 5, this.level = "Beginner"});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  List<Pose> _poses = [];
  String _currentStatus = "Getting ready...";
  late String _targetPoseName;
  double _accuracy = 0.0;
  
  late PoseDetector _poseDetector;
  final FlutterTts _tts = FlutterTts();
  Timer? _ttsTimer;
  Timer? _sessionTimer;
  int _secondsRemaining = 0;
  int _prepCountdown = 3;
  bool _isPrepping = false;
  bool _showBackgroundGuide = true;
  bool _showOnboardingGuide = true;
  DateTime? _lastProcessedTime;
  InputImageRotation? _currentRotation;
  Size? _imageSize;
  
  List<dynamic> _steps = [];
  int _currentStepIndex = 0;
  bool _stepCompleted = false;
  DateTime? _stepStartTime;
  int _errorFrameCount = 0;
  String? _lastSpokenMessage;

  @override
  void initState() {
    super.initState();
    _targetPoseName = widget.pose.name;
    _secondsRemaining = widget.durationMins * 60;
    _initializePoseDetector();
    _initializeCamera();
    _setupScreen();
  }

  Future<void> _setupScreen() async {
    await _initializeTTS();
    await _loadPoseRules();
    
    if (!mounted) return;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _speakInstruction(langProvider.currentLanguage == 'hi'
        ? "आसन शुरू करने से पहले, अपना फोन लगभग 6 फीट दूर रखें और अपना पूरा शरीर कैमरा में दिखाएं।"
        : langProvider.currentLanguage == 'te'
            ? "ఆసనం ప్రారంభించే ముందు, మీ ఫోన్‌ను సుమారు 6 అడుగుల దూరంలో ఉంచండి మరియు మీ పూర్తి శరీరాన్ని కెమెరాలో చూపించండి."
            : "Before beginning, please place your phone 6 feet away and make sure your entire body is visible.");
  }

  void _startPrepCountdown() {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _speakInstruction(langProvider.currentLanguage == 'hi' 
        ? "तैयार हो जाइए! 3, 2, 1 में शुरू हो रहा है" 
        : langProvider.currentLanguage == 'te'
            ? "సిద్ధంగా ఉండండి! మూడు, రెండు, ఒకటి లో ప్రారంభమవుతుంది"
            : "Get ready! Starting in 3, 2, 1");
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepCountdown > 1) {
        setState(() => _prepCountdown--);
      } else {
        timer.cancel();
        setState(() => _isPrepping = false);
        _startSessionTimer();
        String initialMsg = langProvider.currentLanguage == 'hi' 
            ? "शुरू करें! " 
            : langProvider.currentLanguage == 'te'
                ? "ప్రారంభించండి! "
                : "Go! ";
        if (_steps.isNotEmpty && _steps[0]['instruction'] != null) {
          initialMsg += langProvider.translateDynamic(_steps[0]['instruction'].toString());
        }
        _tts.speak(initialMsg);
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _completeSession();
      }
    });
  }

  void _completeSession() {
    _sessionTimer?.cancel();
    setState(() { 
      _currentStatus = "⏱️ Time's Up! Workout Complete. Namaste."; 
      _accuracy = 1.0; 
      _currentStepIndex = _steps.length; // Stop processing steps
    });
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _speakInstruction(langProvider.currentLanguage == 'hi'
        ? "समय समाप्त। वर्कआउट पूरा हुआ। बहुत बढ़िया। नमस्ते।"
        : langProvider.currentLanguage == 'te'
            ? "సమయం ముగిసింది. వ్యాయామం పూర్తయింది. బాగా చేసారు. నమస్తే."
            : "Time is up. Workout complete. Well done. Namaste.");
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Returns the image path for the current step's background guide.
  // Logic: Early steps (prep/setup) → show a "starting position" image.
  //        Later steps (final pose)  → show the actual completed pose image.
  // This gives a step-by-step visual journey matching exactly what user should do.
  String _getStepGuideImage() {
    final String pn = widget.pose.name.toLowerCase();
    final int totalSteps = _steps.length;
    final int step = _currentStepIndex;

    // The "transition point" — after halfway, show the final pose
    final bool isEarlyStep = totalSteps == 0 || step < (totalSteps / 2).ceil();

    // ── Map of pose-name keyword → final pose image asset ──────────────────
    final Map<String, String> finalImages = {
      'tree':              'assets/images/tree_pose.png',
      'warrior i':         'assets/images/warrior_pose_1.png',
      'warrior ii':        'assets/images/warrior_pose.png',
      'warrior iii':       'assets/images/warrior3_pose.png',
      'warrior':           'assets/images/warrior_pose.png',
      'triangle':          'assets/images/triangle_pose.png',
      'chair':             'assets/images/chair_pose.png',
      'plank':             'assets/images/plank_pose.png',
      'side plank':        'assets/images/side_plank.png',
      'cobra':             'assets/images/cobra_pose.png',
      'child':             'assets/images/child_pose.png',
      'cat':               'assets/images/cat_cow.png',
      'cow':               'assets/images/cat_cow.png',
      'lotus':             'assets/images/lotus_pose.png',
      'surya':             'assets/images/category_surya.png',
      'savasana':          'assets/images/savasana.png',
      'goddess':           'assets/images/goddess_pose.png',
      'camel':             'assets/images/camel_pose.png',
      'crow':              'assets/images/crow_pose.png',
      'chaturanga':        'assets/images/chaturanga.png',
      'bow':               'assets/images/bow_pose.png',
      'dolphin':           'assets/images/dolphin_pose.png',
      'boat':              'assets/images/boat_pose.png',
      'butterfly':         'assets/images/butterfly_pose.png',
      'downward':          'assets/images/downward_dog.png',
      'bridge':            'assets/images/bridge_pose.png',
      'extended side':     'assets/images/extended_side_angle.png',
      'half moon':         'assets/images/half_moon.png',
      'pigeon':            'assets/images/pigeon_pose.png',
      'garland':           'assets/images/garland_pose.png',
      'eagle':             'assets/images/eagle_pose.png',
      'fish':              'assets/images/fish_pose.png',
      'frog':              'assets/images/frog_pose.png',
      'anulom':            'assets/images/lotus_pose.png',
      'kapalbhati':        'assets/images/lotus_pose.png',
      'bhramari':          'assets/images/lotus_pose.png',
      'deep breath':       'assets/images/lotus_pose.png',
      'lion':              'assets/images/lotus_pose.png',
      'neck':              'assets/images/lotus_pose.png',
      'shoulder roll':     'assets/images/lotus_pose.png',
      'wrist':             'assets/images/lotus_pose.png',
      'chair twist':       'assets/images/lotus_pose.png',
    };

    // ── Determine the starting position image for early steps ──────────────
    String floorPrep = 'assets/images/lotus_pose.png';
    String lyingPrep = 'assets/images/savasana.png';
    String standingPrep = 'assets/images/mountain_step1.png';
    String tablePrep = 'assets/images/plank_step1.png';
    
    // ── Find the matching final image ──────────────────────────────────────
    String finalImage = widget.pose.imageUrl;
    for (final entry in finalImages.entries) {
      if (pn.contains(entry.key)) {
        finalImage = entry.value;
        break;
      }
    }
    
    // Breathing & Sitting Stretches
    if (pn.contains('breathing') || pn.contains('anulom') || pn.contains('kapalbhati') || pn.contains('neck') || pn.contains('shoulder') || pn.contains('wrist') || pn.contains('lion') || pn.contains('twist')) {
      return floorPrep;
    }

    if (pn.contains('bhramari')) {
      return step == 0 ? 'assets/images/bhramari_step1.png' : 'assets/images/bhramari_step2.png';
    }
    if (pn.contains('mountain')) {
      return step <= 1 ? 'assets/images/mountain_step1.png' : 'assets/images/mountain_step2.png';
    }
    if (pn.contains('tree')) {
      if (step <= 1) return standingPrep;
      if (step == 2) return 'assets/images/tree_step1.png';
      if (step == 3) return 'assets/images/tree_step2.png';
      return 'assets/images/tree_step3.png';
    }
    if (pn.contains('warrior i') && !pn.contains('ii')) {
      return step <= 1 ? 'assets/images/warrior1_step1.png' : 'assets/images/warrior1_step2.png';
    }
    if (pn.contains('warrior ii')) {
      return step == 0 ? standingPrep : (step <= 2 ? 'assets/images/warrior1_step1.png' : 'assets/images/warrior_pose.png');
    }
    if (pn.contains('warrior iii')) {
      return step == 0 ? standingPrep : 'assets/images/warrior3_pose.png';
    }
    if (pn.contains('triangle') || pn.contains('extended side') || pn.contains('half moon') || pn.contains('goddess')) {
      if (step == 0) return standingPrep;
      if (step <= 2) return 'assets/images/warrior1_step1.png';
      if (pn.contains('triangle')) return 'assets/images/triangle_pose.png';
      if (pn.contains('extended')) return 'assets/images/extended_side_angle.png';
      if (pn.contains('half')) return 'assets/images/half_moon.png';
      if (pn.contains('goddess')) return 'assets/images/goddess_pose.png';
    }
    if (pn.contains('chair')) {
      return step == 0 ? standingPrep : (step <= 2 ? 'assets/images/mountain_step2.png' : 'assets/images/chair_pose.png');
    }
    if (pn.contains('plank') && !pn.contains('side')) {
      return step == 0 ? tablePrep : 'assets/images/plank_step2.png';
    }
    if (pn.contains('side plank')) {
      return step == 0 ? tablePrep : (step == 1 ? 'assets/images/plank_step2.png' : 'assets/images/side_plank.png');
    }
    if (pn.contains('chaturanga')) {
      return step == 0 ? tablePrep : (step == 1 ? 'assets/images/plank_step2.png' : 'assets/images/chaturanga.png');
    }
    if (pn.contains('cobra')) {
      return step <= 1 ? lyingPrep : (step == 2 ? 'assets/images/cobra_step1.png' : 'assets/images/cobra_pose.png');
    }
    if (pn.contains('bow')) {
      return step <= 1 ? lyingPrep : (step == 2 ? 'assets/images/bow_step1.png' : 'assets/images/bow_pose.png');
    }
    if (pn.contains('bridge')) {
      return step <= 1 ? lyingPrep : (step == 2 ? 'assets/images/bridge_step1.png' : 'assets/images/bridge_pose.png');
    }
    if (pn.contains('fish')) {
      return step <= 1 ? lyingPrep : (step == 2 ? 'assets/images/bridge_step1.png' : 'assets/images/fish_pose.png');
    }
    if (pn.contains('child')) {
      return step <= 1 ? floorPrep : (step == 2 ? 'assets/images/child_step1.png' : 'assets/images/child_pose.png');
    }
    if (pn.contains('camel')) {
      return step <= 1 ? floorPrep : (step == 2 ? 'assets/images/child_step1.png' : 'assets/images/camel_pose.png');
    }
    if (pn.contains('downward')) {
      return step == 0 ? tablePrep : (step == 1 ? 'assets/images/downward_step1.png' : 'assets/images/downward_dog.png');
    }
    if (pn.contains('dolphin')) {
      return step == 0 ? tablePrep : (step <= 2 ? 'assets/images/downward_step1.png' : 'assets/images/dolphin_pose.png');
    }
    if (pn.contains('pigeon')) {
      return step == 0 ? tablePrep : (step <= 2 ? 'assets/images/downward_step1.png' : 'assets/images/pigeon_pose.png');
    }
    if (pn.contains('cat') || pn.contains('cow')) {
      return step == 0 ? tablePrep : 'assets/images/cat_cow.png';
    }
    if (pn.contains('frog')) {
      return step == 0 ? tablePrep : 'assets/images/garland_pose.png';
    }
    if (pn.contains('crow')) {
      return step == 0 ? tablePrep : 'assets/images/crow_pose.png';
    }
    if (pn.contains('surya')) {
      if (step == 0) return standingPrep;
      if (step == 1) return 'assets/images/mountain_step2.png';
      if (step == 2) return 'assets/images/warrior1_step1.png';
      if (step == 3) return 'assets/images/plank_step2.png';
      if (step == 4) return 'assets/images/cobra_step1.png';
      return standingPrep;
    }
    if (pn.contains('eagle')) {
      return step <= 1 ? standingPrep : 'assets/images/eagle_pose.png';
    }
    if (pn.contains('garland')) {
      return step <= 1 ? standingPrep : 'assets/images/garland_pose.png';
    }
    if (pn.contains('boat')) {
      return step <= 1 ? lyingPrep : 'assets/images/boat_pose.png';
    }
    if (pn.contains('butterfly')) {
      return step <= 1 ? floorPrep : 'assets/images/butterfly_pose.png';
    }
    if (pn.contains('savasana') || pn.contains('rest')) {
      return lyingPrep;
    }

    // Default fallback
    return floorPrep;
  }

  List<Widget> _buildFocusHighlights(LanguageProvider langProvider) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return [];
    
    final currentStep = _steps[_currentStepIndex];
    final rules = currentStep['rules'] as List<dynamic>? ?? [];
    if (rules.isEmpty) return [];
    
    List<Widget> highlights = [];
    
    for (var rule in rules) {
      final joint = rule['joint']?.toString().toLowerCase() ?? '';
      Alignment align = Alignment.center;
      String label = "";
      
      if (joint.contains('arm') || joint.contains('elbow') || joint.contains('shoulder') || joint.contains('wrist')) {
        align = const Alignment(0.0, -0.4); // Upper chest/arms area
        label = langProvider.currentLanguage == 'hi' ? "हाथों की स्थिति" : langProvider.currentLanguage == 'te' ? "చేతులపై దృష్టి" : "Focus: Arms";
      } else if (joint.contains('knee') || joint.contains('hip') || joint.contains('leg')) {
        align = const Alignment(0.0, 0.4); // Lower body / legs area
        label = langProvider.currentLanguage == 'hi' ? "पैरों की स्थिति" : langProvider.currentLanguage == 'te' ? "కాళ్లపై దృష్టి" : "Focus: Legs";
      } else if (joint.contains('ankle') || joint.contains('foot') || joint.contains('feet')) {
        align = const Alignment(0.0, 0.7); // Foot area
        label = langProvider.currentLanguage == 'hi' ? "पैरों पर ध्यान दें" : langProvider.currentLanguage == 'te' ? "పాదాల స్థానం" : "Focus: Feet";
      } else if (joint.contains('spine') || joint.contains('back') || joint.contains('chest')) {
        align = const Alignment(0.0, 0.0); // Spine / Core
        label = langProvider.currentLanguage == 'hi' ? "कमर सीधी रखें" : langProvider.currentLanguage == 'te' ? "వెన్నుముక నిటారుగా" : "Focus: Posture";
      } else {
        continue;
      }
      
      highlights.add(
        PulsingFocusHighlight(
          key: ValueKey("${_currentStepIndex}_${joint}"),
          alignment: align,
          label: label,
        ),
      );
    }
    
    return highlights;
  }

  Future<void> _loadPoseRules() async {
    try {
      final String response = await rootBundle.loadString('assets/data/pose_rules.json');
      final data = json.decode(response);
      final poseData = data.firstWhere((e) => e['poseName'] == _targetPoseName, orElse: () => null);
      if (poseData != null) {
        setState(() {
          _steps = poseData['steps'];
          _currentStatus = _steps[0]['instruction'];
        });
      } else {
        // Fallback for poses without specific AI rules
        setState(() {
          _steps = [
            {"stepName": "Practice", "instruction": "Follow the guide image and perfect your form!", "rules": []}
          ];
          _currentStatus = "Follow the guide image!";
        });
      }
    } catch (e) { debugPrint("JSON Load Error: $e"); }
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base, mode: PoseDetectionMode.stream));
  }

  Future<void> _initializeTTS() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    if (langProvider.currentLanguage == 'hi') {
      await _tts.setLanguage("hi-IN");
    } else if (langProvider.currentLanguage == 'te') {
      await _tts.setLanguage("te-IN");
    } else {
      await _tts.setLanguage("en-US");
    }
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _controller = CameraController(
      front, 
      ResolutionPreset.low,  // LOW resolution (320x240) drastically reduces GC pressure and BufferQueue timeouts
      enableAudio: false, 
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888
    );
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _controller!.startImageStream(_processCameraImage);
    } catch (e) { debugPrint("Camera Error: $e"); }
  }

  @override
  void dispose() { 
    _ttsTimer?.cancel(); 
    _sessionTimer?.cancel();
    _controller?.dispose(); 
    _poseDetector.close(); 
    super.dispose(); 
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _steps.isEmpty || _isPrepping || _showOnboardingGuide) return;

    // THROTTLE: 1500ms between frames — gives Android GC time to breathe
    final now = DateTime.now();
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 1500) {
      return;
    }
    _lastProcessedTime = now;
    _isProcessing = true;

    // ── Extract bytes SYNCHRONOUSLY before the camera reclaims the buffer ──
    // This MUST happen here, in the camera stream callback, before we go async.
    final InputImage? inputImage = _buildInputImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    // ── Run ML Kit off the main thread ─────────────────────────────────────
    try {
      final poses = await Future(() => _poseDetector.processImage(inputImage)).then((f) => f);

      if (!mounted) return;
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _poses = poses;
        _currentRotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation90deg;
        _imageSize = inputImage.metadata?.size;
      });

      if (poses.isNotEmpty) {
        _updateStepProgress(poses.first);
      } else {
        if (!_isPrepping && !_showOnboardingGuide && _currentStepIndex < _steps.length) {
          _stepStartTime = null;
          setState(() {
            _currentStatus = langProvider.currentLanguage == 'hi'
                ? 'कोई शरीर नहीं मिला। कृपया कैमरा के सामने आएं।'
                : langProvider.currentLanguage == 'te'
                    ? 'శరీరం కనుగొనబడలేదు. దయచేసి ఫ్రేమ్‌లోకి వెళ్ళండి.'
                    : 'No body detected. Please step into frame.';
            _accuracy = 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint("ML Kit Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  /// Build InputImage synchronously from CameraImage.
  /// For Android NV21: image has a SINGLE plane — use bytes directly.
  /// For iOS BGRA8888: concatenate all planes.
  InputImage? _buildInputImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      // Android front camera: rotation = sensorOrientation
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) rotation = InputImageRotation.rotation90deg;

    if (image.planes.isEmpty) return null;

    if (Platform.isAndroid) {
      // NV21 from Android camera is always a single-plane packed buffer.
      // DO NOT concatenate planes — that gives wrong data and causes
      // "ImageFormat is not supported" from ML Kit.
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // iOS — BGRA8888, concatenate all planes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      return InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
  }

  void _updateStepProgress(Pose pose) {
    if (_currentStepIndex >= _steps.length) return;

    final currentStep = _steps[_currentStepIndex];
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final lang = langProvider.currentLanguage;

    // ── TIMED ADVANCEMENT: Only for poses where camera TRULY cannot detect ──
    // (fine finger gestures, breath rhythm, nostril switching, eye closure, etc.)
    const trulyUndetectablePoses = [
      'anulom', 'kapalbhati', 'bhramari', 'deep breath', 'lion breath',
      'neck stretch', 'shoulder roll', 'wrist stretch', 'chair twist',
    ];
    final bool isTimedPose = trulyUndetectablePoses.any(
        (k) => _targetPoseName.toLowerCase().contains(k));

    if (isTimedPose) {
      _stepStartTime ??= DateTime.now();
      final elapsed = DateTime.now().difference(_stepStartTime!).inSeconds;
      final bool isBreathing = ['anulom', 'kapalbhati', 'bhramari', 'deep breath', 'lion breath']
          .any((k) => _targetPoseName.toLowerCase().contains(k));
      final int holdSecs = isBreathing ? 15 : 10;
      final int remaining = (holdSecs - elapsed).clamp(0, holdSecs);

      final String stepInstruction = langProvider.translateDynamic(currentStep['instruction'].toString());
      if (_currentStepIndex == _steps.length - 1) {
        setState(() {
          _accuracy = 0.90;
          _currentStatus = "🧘 $stepInstruction... ${_formatTime(_secondsRemaining)}";
        });
      } else if (elapsed >= holdSecs) {
        _moveToNextStep();
      } else {
        setState(() {
          _accuracy = 0.85;
          _currentStatus = "🧘 $stepInstruction — ${remaining}s";
        });
      }
      return;
    }

    // ── CAMERA-VERIFIED POSE DETECTION: All other poses ─────────────────────
    // Accumulate rules from Step 0 → _currentStepIndex (later rules override earlier for same joint)
    final Map<String, Map<String, dynamic>> activeRulesMap = {};
    for (int i = 0; i <= _currentStepIndex; i++) {
      final stepRules = (_steps[i]['rules'] as List<dynamic>);
      for (var rule in stepRules) {
        activeRulesMap[rule['joint'] as String] = Map<String, dynamic>.from(rule);
      }
    }

    // If this pose has no trackable rules at all, use a minimum hold timer
    if (activeRulesMap.isEmpty) {
      _stepStartTime ??= DateTime.now();
      final elapsed = DateTime.now().difference(_stepStartTime!).inSeconds;
      final int holdSecs = 6;
      final String stepInstruction = langProvider.translateDynamic(currentStep['instruction'].toString());
      final String holdMsg = lang == 'hi' ? 'मुद्रा बनाए रखें' : lang == 'te' ? 'పోజ్ పట్టుకోండి' : 'Hold the pose';
      if (_currentStepIndex == _steps.length - 1) {
        setState(() { _accuracy = 0.8; _currentStatus = "$holdMsg... ${_formatTime(_secondsRemaining)}"; });
      } else if (elapsed >= holdSecs) {
        _moveToNextStep();
      } else {
        setState(() { _accuracy = 0.8; _currentStatus = "$stepInstruction — ${holdSecs - elapsed}s"; });
      }
      return;
    }

    // Evaluate all accumulated rules against current camera landmarks
    bool allRulesPassed = true;
    String feedback = langProvider.translateDynamic(currentStep['instruction'].toString());

    for (var rule in activeRulesMap.values) {
      double? angle = _calculateAngle(pose, rule['joint']);

      // Level tolerance: Beginner gets ±12°, Intermediate ±6°, Advanced ±0°
      double tolerance = 0;
      if (widget.level == "Beginner") tolerance = 12;
      if (widget.level == "Intermediate") tolerance = 6;

      final String positionMsg = lang == 'hi'
          ? 'खुद को कैमरे में स्पष्ट रूप से दिखाएं'
          : lang == 'te'
              ? 'కెమెరా వీక్షణంలో మిమ్మల్ని స్పష్టంగా ఉంచుకోండి'
              : 'Position yourself clearly in the camera view';

      if (angle == null) {
        allRulesPassed = false;
        feedback = positionMsg;
        break;
      } else if (angle < (rule['idealMin'] - tolerance) || angle > (rule['idealMax'] + tolerance)) {
        allRulesPassed = false;
        feedback = langProvider.translateDynamic(rule['messageLow'] ?? rule['messageHigh'] ?? currentStep['instruction']);
        break;
      }
    }

    if (allRulesPassed) {
      _errorFrameCount = 0;
      _stepStartTime ??= DateTime.now();
      final duration = DateTime.now().difference(_stepStartTime!).inSeconds;

      // Required hold time: must maintain CORRECT posture for this long before advancing
      int requiredHold = 5;  // Beginner: 5 seconds
      if (widget.level == "Intermediate") requiredHold = 8;
      if (widget.level == "Advanced") requiredHold = 12;

      final String perfectMsg = lang == 'hi' ? '✅ बहुत अच्छे!' : lang == 'te' ? '✅ చాలా బాగుంది!' : '✅ Perfect!';
      final String holdMsg = lang == 'hi' ? 'थोड़ी देर रुकें' : lang == 'te' ? 'కొంచెం సేపు ఆగండి' : 'Hold for';

      if (_currentStepIndex == _steps.length - 1) {
        setState(() {
          _accuracy = 1.0;
          _currentStatus = "$perfectMsg ${lang == 'hi' ? 'रखें...' : lang == 'te' ? 'ఉంచండి...' : 'Keep holding...'} ${_formatTime(_secondsRemaining)}";
        });
      } else if (duration >= requiredHold) {
        _moveToNextStep();
      } else {
        setState(() {
          _accuracy = 1.0;
          _currentStatus = "$perfectMsg $holdMsg ${requiredHold - duration}s...";
        });
      }
    } else {
      // Wrong posture — reset hold timer, show camera-detected feedback
      _stepStartTime = null;
      setState(() { _accuracy = 0.4; _currentStatus = feedback; });
      
      // Filter out temporary landmark dropouts or momentary wobbles (glitch smoothing)
      _errorFrameCount++;
      if (_errorFrameCount >= 12) { // Must be wrong posture for at least ~0.5s before generating voice alert
        _provideVoiceFeedback(feedback);
      }
    }
  }

  void _moveToNextStep() {
    _stepStartTime = null;
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _currentStatus = _steps[_currentStepIndex]['instruction'];
      });
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      // Speak "Perfect" + next instruction in the selected language
      final perfectWord = langProvider.currentLanguage == 'hi'
          ? 'शाबाश! '
          : langProvider.currentLanguage == 'te'
              ? 'అద్భుతంగా ఉంది! '
              : 'Perfect! ';
      final instruction = langProvider.translateDynamic(_steps[_currentStepIndex]['instruction'].toString());
      _tts.speak('$perfectWord$instruction');
    }
  }

  double? _calculateAngle(Pose pose, String joint) {
    final landmarks = pose.landmarks;

    double? getValidAngle(PoseLandmark? p1, PoseLandmark? p2, PoseLandmark? p3, {bool requireUpright = false}) {
      if (p1 == null || p2 == null || p3 == null) return null;
      
      // Strict check: limbs must be clearly visible (likelihood > 0.45) to prevent guessing when sitting/lying down
      if (p1.likelihood < 0.45 || p2.likelihood < 0.45 || p3.likelihood < 0.45) return null;
      
      // If we require the person to be standing/upright (e.g. spine checks),
      // the shoulder (p1) must be physically above the hip (p2). In ML Kit Y=0 is the top.
      if (requireUpright && p1.y > p2.y - 30) return null;

      return _getAngle(p1, p2, p3);
    }

    if (joint.contains("arm")) {
      final s = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
      final e = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
      final w = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
      return getValidAngle(s, e, w);
    } else if (joint.contains("knee") || joint.contains("leg") || joint.contains("bent")) {
      final h = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
      final k = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee];
      final a = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];
      return getValidAngle(h, k, a);
    } else if (joint == "spine" || joint == "body_line") {
      final s = landmarks[PoseLandmarkType.leftShoulder];
      final h = landmarks[PoseLandmarkType.leftHip];
      final k = landmarks[PoseLandmarkType.leftKnee];
      
      // Enforce strict upright check only for standing vertical poses.
      // Dynamic, inverted, horizontal, or bending poses (like Surya Namaskar, Triangle Pose, Camel, Crow, etc.) should bypass this.
      final uprightStandingPoses = [
        "Mountain Pose", "Tree Pose", "Warrior I", "Warrior II", 
        "Chair Pose", "Goddess Pose"
      ];
      bool requireUpright = uprightStandingPoses.contains(_targetPoseName);
      
      // Special case for sitting upright poses:
      // When sitting cross-legged (Lotus, Deep Breathing, etc.), the knee is horizontal to the hip.
      // So shoulder-hip-knee angle is ~90 deg, but the rules expect 155-180 (straight back).
      // We substitute the knee with an imaginary point directly below the hip to measure torso verticality!
      final sittingUprightPoses = [
        "Lotus Pose", "Deep Breathing", "Anulom Vilom", "Kapalbhati",
        "Bhramari", "Neck Stretch", "Butterfly Pose", "Chair Twist", "Lion Breath", "Boat Pose"
      ];
      
      if (sittingUprightPoses.contains(_targetPoseName)) {
        // Enforce basic visibility and upright checks manually before substituting points
        if (s == null || h == null) return null;
        if (s.likelihood < 0.45 || h.likelihood < 0.45) return null;
        if (requireUpright && s.y > h.y - 30) return null;
        
        return _getAngleFromPoints(s.x, s.y, h.x, h.y, h.x, h.y + 100);
      }
      
      return getValidAngle(s, h, k, requireUpright: requireUpright);
    } else if (joint == "arms") {
      final s = landmarks[PoseLandmarkType.leftShoulder];
      final e = landmarks[PoseLandmarkType.leftElbow];
      final w = landmarks[PoseLandmarkType.leftWrist];
      return getValidAngle(s, e, w);
    }
    return null;
  }

  double _getAngleFromPoints(double p1x, double p1y, double p2x, double p2y, double p3x, double p3y) {
    double angle = (math.atan2(p3y - p2y, p3x - p2x) - math.atan2(p1y - p2y, p1x - p2x)).abs();
    angle = angle * 180 / math.pi;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  double _getAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    return _getAngleFromPoints(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
  }

  void _speakInstruction(String msg) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _tts.speak(langProvider.translateDynamic(msg));
  }

  void _provideVoiceFeedback(String message) {
    if (_ttsTimer?.isActive ?? false) return;
    
    // Dynamically calculate the cooldown:
    // If the message is the same as the last spoken error, make the user wait 18 seconds to avoid voice fatigue.
    // Otherwise, enforce a relaxed 10-second spacing between different voice corrections.
    final int cooldownSecs = (message == _lastSpokenMessage) ? 18 : 10;
    _ttsTimer = Timer(Duration(seconds: cooldownSecs), () {});
    
    _lastSpokenMessage = message;
    
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _tts.speak(langProvider.translateDynamic(message));
  }

  // Convert a landmark to screen coordinates
  Offset _landmarkToScreen(PoseLandmark lm, Size screenSize) {
    final imgSize = _imageSize ?? _controller!.value.previewSize!;
    final rot = _currentRotation ?? InputImageRotation.rotation270deg;
    double x, y;
    
    switch (rot) {
      case InputImageRotation.rotation90deg:
        x = lm.x * screenSize.width / imgSize.height;
        y = lm.y * screenSize.height / imgSize.width;
        break;
      case InputImageRotation.rotation270deg:
        x = screenSize.width - lm.x * screenSize.width / imgSize.height;
        y = lm.y * screenSize.height / imgSize.width;
        break;
      default:
        x = lm.x * screenSize.width / imgSize.width;
        y = lm.y * screenSize.height / imgSize.height;
    }
    // Mirror for front camera
    x = screenSize.width - x;
    return Offset(x.clamp(0, screenSize.width), y.clamp(0, screenSize.height));
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }
    
    // Determine tracking colors
    Color poseColor = _accuracy >= 1.0 ? const Color(0xFF00FF88) : Colors.redAccent;
    Color statusColor = _accuracy >= 1.0 ? const Color(0xFF00FF88) : Colors.orangeAccent;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // CENTERED & ASPECT RATIO BOX for Camera and Landmarks (prevents stretching)
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
                  
                  // Build landmark dots as direct widgets
                  List<Widget> landmarkWidgets = [];
                  if (_poses.isNotEmpty) {
                    final pose = _poses.first;
                    
                    // Draw lines between landmarks
                    final connections = [
                      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
                      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
                      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
                      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
                      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
                      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
                      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
                      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
                      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
                      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
                      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
                      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
                    ];
                    
                    for (final conn in connections) {
                      final lm1 = pose.landmarks[conn[0]];
                      final lm2 = pose.landmarks[conn[1]];
                      if (lm1 != null && lm2 != null) {
                        final p1 = _landmarkToScreen(lm1, widgetSize);
                        final p2 = _landmarkToScreen(lm2, widgetSize);
                        landmarkWidgets.add(
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LinePainter(p1, p2, poseColor),
                            ),
                          ),
                        );
                      }
                    }

                    // Draw dots for each landmark
                    for (final entry in pose.landmarks.entries) {
                      final offset = _landmarkToScreen(entry.value, widgetSize);
                      landmarkWidgets.add(
                        Positioned(
                          left: offset.dx - 6,
                          top: offset.dy - 6,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: poseColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: poseColor.withOpacity(0.5), blurRadius: 8)],
                            ),
                          ),
                        ),
                      );
                    }
                  }
                  
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),

                      // The green target skeleton and background ghost have been removed based on user feedback to ensure the user is perfectly visible.

                      // ── USER'S LIVE SKELETON (detected joints from camera) ─────────
                      ...landmarkWidgets,

                      // ── FOCUS HIGHLIGHT RINGS ─────────────────────────────────────
                      if (_showBackgroundGuide)
                        ..._buildFocusHighlights(langProvider),
                    ],
                  );
                },
              ),
            ),
          ),
          
          // --- TOP STATUS BAR ---
          Positioned(
            top: 50, left: 20, right: 20,
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _steps.isEmpty ? 0 : (_currentStepIndex + 1) / _steps.length, 
                    backgroundColor: Colors.white10, 
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF88)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                // Pose name + detection status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.pose.name.toUpperCase(), 
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF88), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _poses.isEmpty ? Icons.person_search : Icons.check_circle,
                            color: _poses.isEmpty ? Colors.orangeAccent : const Color(0xFF00FF88),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _poses.isEmpty ? "Stand back to show full body" : "Tracking your pose ✓", 
                            style: GoogleFonts.outfit(
                              color: _poses.isEmpty ? Colors.orangeAccent : const Color(0xFF00FF88), 
                              fontSize: 14, fontWeight: FontWeight.bold
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),


          // --- GUIDE IMAGE OVERLAY (Mini Card & Toggle Target) ---
          Positioned(
            top: 160, right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showBackgroundGuide = !_showBackgroundGuide;
                });
              },
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _showBackgroundGuide ? const Color(0xFF00FF88) : Colors.white24, 
                    width: 2
                  ),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
                  image: DecorationImage(image: AssetImage(_getStepGuideImage()), fit: BoxFit.cover),
                ),
                child: Stack(
                  children: [
                    // Eye / Visibility status icon hint
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _showBackgroundGuide ? Icons.visibility : Icons.visibility_off, 
                          color: _showBackgroundGuide ? const Color(0xFF00FF88) : Colors.white54, 
                          size: 16
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // --- BOTTOM COACHING BOX ---
          Positioned(
            bottom: 30, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _accuracy >= 1.0 
                    ? const Color(0xFF00FF88).withOpacity(0.6) 
                    : Colors.white.withOpacity(0.1), 
                  width: 2
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row: step label + timer + guide toggle + close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          langProvider.currentLanguage == 'hi' 
                              ? "चरण ${_currentStepIndex + 1}/${_steps.length}" 
                              : "STEP ${_currentStepIndex + 1}/${_steps.length}", 
                          style: GoogleFonts.outfit(color: const Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Text(_formatTime(_secondsRemaining), 
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _showBackgroundGuide ? Icons.accessibility_new : Icons.accessibility_new_outlined, 
                              color: _showBackgroundGuide ? const Color(0xFF00FF88) : Colors.white54, 
                              size: 22
                            ),
                            onPressed: () {
                              setState(() {
                                _showBackgroundGuide = !_showBackgroundGuide;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Toggle background guide",
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 22), 
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Step dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) => Container(
                      width: i == _currentStepIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i < _currentStepIndex 
                          ? const Color(0xFF00FF88) 
                          : i == _currentStepIndex 
                            ? Colors.white 
                            : Colors.white24,
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  // Step name
                  if (_steps.isNotEmpty && _currentStepIndex < _steps.length)
                    Text(
                      langProvider.translateDynamic(_steps[_currentStepIndex]['stepName'] ?? '').toString().toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  const SizedBox(height: 6),
                  // Main instruction / feedback
                  Text(
                    langProvider.translateDynamic(_currentStatus),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          
          // --- GET READY OVERLAY ---
          if (_isPrepping)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      langProvider.currentLanguage == 'hi' ? "तैयार हो जाएं" : "GET READY", 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Text("$_prepCountdown", style: GoogleFonts.outfit(color: const Color(0xFF00FF88), fontSize: 100, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // --- ONBOARDING PREPARATION GUIDE OVERLAY ---
          if (_showOnboardingGuide)
            Container(
              color: Colors.black.withOpacity(0.92),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Warm welcome and Yoga symbol
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.accessibility_new, color: Color(0xFF00FF88), size: 48),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        langProvider.currentLanguage == 'hi' ? "आसन की तैयारी" : langProvider.currentLanguage == 'te' ? "ఆసన సాధన తయారీ" : "POSE PREPARATION",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF00FF88),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langProvider.translateDynamic(widget.pose.name).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 35),
                      
                      // Checklist items of what to do first:
                      _buildOnboardingStep(
                        icon: Icons.phone_android,
                        title: langProvider.currentLanguage == 'hi' ? "फोन को दूर रखें" : langProvider.currentLanguage == 'te' ? "ఫోన్‌ను దూరంగా ఉంచండి" : "Place Phone 6-8 Feet Away",
                        description: langProvider.currentLanguage == 'hi' 
                          ? "फोन को आंखों के स्तर पर सीधे रखें ताकि पूरा शरीर दिखाई दे।" 
                          : langProvider.currentLanguage == 'te' 
                              ? "పూర్తి శరీరం కెమెరాలో కనిపించేలా ఫోన్‌ను కంటి దూరంలో ఉంచండి." 
                              : "Place your phone upright at eye level on a stable surface.",
                      ),
                      _buildOnboardingStep(
                        icon: Icons.lightbulb_outline,
                        title: langProvider.currentLanguage == 'hi' ? "अच्छा प्रकाश सुनिश्चित करें" : langProvider.currentLanguage == 'te' ? "మంచి వెలుతురును చూసుకోండి" : "Ensure Good Lighting",
                        description: langProvider.currentLanguage == 'hi' 
                          ? "कमरे में रोशनी अच्छी होनी चाहिए ताकि कैमरे को सटीक ट्रैक मिले।" 
                          : langProvider.currentLanguage == 'te' 
                              ? "కెమెరా సరిగ్గా గుర్తించడానికి గదిలో తగినంత వెలుతురు ఉండేలా చూసుకోండి." 
                              : "Ensure the room is well-lit for precise skeletal tracking.",
                      ),
                      _buildOnboardingStep(
                        icon: Icons.center_focus_strong,
                        title: langProvider.currentLanguage == 'hi' ? "गाइड चित्र से संरेखित करें" : langProvider.currentLanguage == 'te' ? "గైడ్ ఇమేజ్‌తో కలవండి" : "Align with the Guide Image",
                        description: langProvider.currentLanguage == 'hi' 
                          ? "कैमरा शुरू होने पर सीधे खड़े होकर गाइड चित्र के साथ खुद को संरेखित करें।" 
                          : langProvider.currentLanguage == 'te' 
                              ? "లైవ్ కెమెరాలో కనిపించే గైడ్ ఇమేజ్‌తో మీ శరీరాన్ని కలపండి." 
                              : "Align your body reflection inside the guide image.",
                      ),
                      
                      const Spacer(),
                      
                      // Glowing green "Start Session" button!
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOnboardingGuide = false;
                            _isPrepping = true;
                          });
                          _startPrepCountdown();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FF88), Color(0xFF00BFFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              langProvider.currentLanguage == 'hi' ? "शुरू करें" : langProvider.currentLanguage == 'te' ? "ప్రారంభించండి" : "LET'S START",
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOnboardingStep({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00FF88), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Simple line painter for skeleton bones
class _LinePainter extends CustomPainter {
  final Offset p1;
  final Offset p2;
  final Color color;
  _LinePainter(this.p1, this.p2, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.p1 != p1 || old.p2 != p2 || old.color != color;
}

// Glowing pulsing visual highlight widget for active step joints
class PulsingFocusHighlight extends StatefulWidget {
  final Alignment alignment;
  final String label;
  const PulsingFocusHighlight({super.key, required this.alignment, required this.label});

  @override
  State<PulsingFocusHighlight> createState() => _PulsingFocusHighlightState();
}

class _PulsingFocusHighlightState extends State<PulsingFocusHighlight> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 30 + (40 * _animation.value),
                    height: 30 + (40 * _animation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(1.0 - _animation.value),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withOpacity(0.3 * (1.0 - _animation.value)),
                          blurRadius: 8,
                        )
                      ],
                    ),
                  ),
                  Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FF88),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5), width: 1.5),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.outfit(
                color: const Color(0xFF00FF88),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw dynamic, glowing, step-wise target posture skeleton shadow
class TargetSkeletonPainter extends CustomPainter {
  final int stepIndex;
  final List<dynamic> steps;
  final String poseName;
  TargetSkeletonPainter({required this.stepIndex, required this.steps, required this.poseName});

  // Pose type detection helpers
  bool get _isSitting => _matchesAny(['lotus', 'butterfly', 'child', 'cat', 'cow', 'boat', 'frog', 'pigeon', 'fish', 'garland', 'sukhasana', 'deep breath', 'anulom', 'kapalbhati', 'bhramari', 'lion', 'wrist', 'neck', 'shoulder roll', 'chair twist']);
  bool get _isLying => _matchesAny(['cobra', 'savasana', 'bow', 'dolphin', 'chaturanga', 'plank', 'side plank', 'bridge', 'downward']);
  bool _matchesAny(List<String> keys) => keys.any((k) => poseName.toLowerCase().contains(k));

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    
    // Define joint points based on active step index
    // We position them relative to the center of the screen
    final center = Offset(w / 2, h * 0.45);
    final double scale = h * 0.45; // Scale size based on height
    
    final glowPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.2)
      ..strokeWidth = 15.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final corePaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.65) // High-visibility core bone lines
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final jointGlowPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final jointCorePaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.fill;

    // ─── BASE positions determined by pose type ───────────────────────────────
    late Offset head, neck, leftShoulder, rightShoulder;
    late Offset leftElbow, rightElbow, leftWrist, rightWrist;
    late Offset leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle;

    if (_isLying) {
      // LYING DOWN – horizontal layout, person on their front/back
      final Offset c = Offset(w * 0.5, h * 0.5);
      head          = c + Offset(-scale * 0.55, -scale * 0.05);
      neck          = c + Offset(-scale * 0.42,  0);
      leftShoulder  = c + Offset(-scale * 0.3,  -scale * 0.08);
      rightShoulder = c + Offset(-scale * 0.3,   scale * 0.08);
      leftElbow     = c + Offset(-scale * 0.15, -scale * 0.12);
      rightElbow    = c + Offset(-scale * 0.15,  scale * 0.12);
      leftWrist     = c + Offset( scale * 0.05, -scale * 0.12);
      rightWrist    = c + Offset( scale * 0.05,  scale * 0.12);
      leftHip       = c + Offset( scale * 0.15, -scale * 0.07);
      rightHip      = c + Offset( scale * 0.15,  scale * 0.07);
      leftKnee      = c + Offset( scale * 0.38, -scale * 0.07);
      rightKnee     = c + Offset( scale * 0.38,  scale * 0.07);
      leftAnkle     = c + Offset( scale * 0.58, -scale * 0.07);
      rightAnkle    = c + Offset( scale * 0.58,  scale * 0.07);
    } else if (_isSitting) {
      // SITTING – torso upright, cross-legged (padmasana-style)
      final Offset c = Offset(w * 0.5, h * 0.42);
      head          = c + Offset(0, -scale * 0.38);
      neck          = c + Offset(0, -scale * 0.28);
      leftShoulder  = c + Offset(-scale * 0.15, -scale * 0.22);
      rightShoulder = c + Offset( scale * 0.15, -scale * 0.22);
      leftElbow     = c + Offset(-scale * 0.22, -scale * 0.04);
      rightElbow    = c + Offset( scale * 0.22, -scale * 0.04);
      // Hands resting gently on knees
      leftWrist     = c + Offset(-scale * 0.28,  scale * 0.30);
      rightWrist    = c + Offset( scale * 0.28,  scale * 0.30);
      leftHip       = c + Offset(-scale * 0.10,  scale * 0.12);
      rightHip      = c + Offset( scale * 0.10,  scale * 0.12);
      // Knees spread wide to the sides (natural cross-legged)
      leftKnee      = c + Offset(-scale * 0.30,  scale * 0.28);
      rightKnee     = c + Offset( scale * 0.30,  scale * 0.28);
      // Ankles cross inward at center (not wider than knees!)
      leftAnkle     = c + Offset( scale * 0.06,  scale * 0.42);
      rightAnkle    = c + Offset(-scale * 0.06,  scale * 0.42);
    } else {
      // STANDING – default upright Mountain Pose
      final Offset c = Offset(w * 0.5, h * 0.45);
      head          = c + Offset(0, -scale * 0.40);
      neck          = c + Offset(0, -scale * 0.30);
      leftShoulder  = c + Offset(-scale * 0.15, -scale * 0.25);
      rightShoulder = c + Offset( scale * 0.15, -scale * 0.25);
      leftElbow     = c + Offset(-scale * 0.20, -scale * 0.05);
      rightElbow    = c + Offset( scale * 0.20, -scale * 0.05);
      leftWrist     = c + Offset(-scale * 0.20,  scale * 0.15);
      rightWrist    = c + Offset( scale * 0.20,  scale * 0.15);
      leftHip       = c + Offset(-scale * 0.08,  scale * 0.15);
      rightHip      = c + Offset( scale * 0.08,  scale * 0.15);
      leftKnee      = c + Offset(-scale * 0.08,  scale * 0.50);
      rightKnee     = c + Offset( scale * 0.08,  scale * 0.50);
      leftAnkle     = c + Offset(-scale * 0.08,  scale * 0.85);
      rightAnkle    = c + Offset( scale * 0.08,  scale * 0.85);
    }

    // Let's modify the pose dynamically based on the step index!
    final String p = poseName.toLowerCase();

    // ── STANDING POSES ──────────────────────────────────────────────────────
    if (p.contains('tree')) {
      if (stepIndex >= 2) { rightKnee = rightKnee + Offset(scale*0.10, 0); rightAnkle = leftKnee + Offset(0, scale*0.02); }
      if (stepIndex == 3) { leftWrist = neck + Offset(-scale*0.04, scale*0.05); rightWrist = neck + Offset(scale*0.04, scale*0.05); leftElbow = leftShoulder + Offset(scale*0.05, scale*0.12); rightElbow = rightShoulder + Offset(-scale*0.05, scale*0.12); }
      if (stepIndex >= 4) { leftWrist = head + Offset(-scale*0.08, -scale*0.12); rightWrist = head + Offset(scale*0.08, -scale*0.12); leftElbow = leftShoulder + Offset(-scale*0.05, -scale*0.3); rightElbow = rightShoulder + Offset(scale*0.05, -scale*0.3); }
    } else if (p.contains('warrior')) {
      if (stepIndex >= 1) { leftAnkle = leftAnkle + Offset(-scale*0.15, 0); rightAnkle = rightAnkle + Offset(scale*0.15, 0); leftKnee = leftKnee + Offset(-scale*0.08, -scale*0.05); rightKnee = rightKnee + Offset(scale*0.08, scale*0.05); }
      if (stepIndex >= 3 && (p.contains('warrior i') || p.contains('warrior 1'))) { leftWrist = head + Offset(-scale*0.06, -scale*0.15); rightWrist = head + Offset(scale*0.06, -scale*0.15); leftElbow = leftShoulder + Offset(-scale*0.04, -scale*0.28); rightElbow = rightShoulder + Offset(scale*0.04, -scale*0.28); }
      if (stepIndex >= 3 && (p.contains('warrior ii') || p.contains('warrior 2'))) { leftWrist = leftShoulder + Offset(-scale*0.3, 0); rightWrist = rightShoulder + Offset(scale*0.3, 0); leftElbow = leftShoulder + Offset(-scale*0.15, 0); rightElbow = rightShoulder + Offset(scale*0.15, 0); }
    } else if (p.contains('triangle')) {
      if (stepIndex >= 1) { leftAnkle = leftAnkle + Offset(-scale*0.18, 0); rightAnkle = rightAnkle + Offset(scale*0.18, 0); }
      if (stepIndex >= 2) { leftWrist = leftAnkle + Offset(0, -scale*0.05); leftElbow = leftHip + Offset(-scale*0.05, scale*0.05); rightWrist = head + Offset(scale*0.05, -scale*0.15); rightElbow = rightShoulder + Offset(scale*0.08, -scale*0.12); }
    } else if (p.contains('chair')) {
      if (stepIndex >= 1) { leftKnee = leftKnee + Offset(0, -scale*0.1); rightKnee = rightKnee + Offset(0, -scale*0.1); }
      if (stepIndex >= 2) { leftWrist = head + Offset(-scale*0.06, -scale*0.15); rightWrist = head + Offset(scale*0.06, -scale*0.15); leftElbow = leftShoulder + Offset(-scale*0.04, -scale*0.25); rightElbow = rightShoulder + Offset(scale*0.04, -scale*0.25); }
    } else if (p.contains('eagle')) {
      if (stepIndex >= 1) { leftKnee = leftKnee + Offset(scale*0.05, -scale*0.05); rightAnkle = leftKnee + Offset(scale*0.02, scale*0.1); }
      if (stepIndex >= 2) { leftElbow = rightElbow + Offset(-scale*0.02, -scale*0.08); leftWrist = rightWrist + Offset(scale*0.02, -scale*0.05); }
    } else if (p.contains('goddess')) {
      leftAnkle = leftAnkle + Offset(-scale*0.2, 0); rightAnkle = rightAnkle + Offset(scale*0.2, 0);
      leftKnee = leftKnee + Offset(-scale*0.15, -scale*0.08); rightKnee = rightKnee + Offset(scale*0.15, -scale*0.08);
      if (stepIndex >= 2) { leftWrist = leftShoulder + Offset(-scale*0.2, 0); rightWrist = rightShoulder + Offset(scale*0.2, 0); leftElbow = leftShoulder + Offset(-scale*0.12, scale*0.06); rightElbow = rightShoulder + Offset(scale*0.12, scale*0.06); }
    } else if (p.contains('half moon')) {
      if (stepIndex >= 2) { leftAnkle = leftHip + Offset(-scale*0.3, scale*0.05); rightAnkle = rightAnkle + Offset(0, scale*0.02); rightKnee = rightKnee + Offset(0, -scale*0.1); leftKnee = leftHip + Offset(-scale*0.15, scale*0.05); }
      if (stepIndex >= 3) { rightWrist = head + Offset(scale*0.05, -scale*0.12); rightElbow = rightShoulder + Offset(scale*0.05, -scale*0.2); }
    } else if (p.contains('camel')) {
      if (stepIndex >= 2) { head = head + Offset(0, scale*0.1); neck = neck + Offset(0, scale*0.08); }
      if (stepIndex >= 3) { leftWrist = leftAnkle + Offset(-scale*0.02, 0); rightWrist = rightAnkle + Offset(scale*0.02, 0); leftElbow = leftHip + Offset(-scale*0.08, scale*0.1); rightElbow = rightHip + Offset(scale*0.08, scale*0.1); }
    } else if (p.contains('crow')) {
      if (stepIndex >= 2) { leftKnee = leftElbow + Offset(-scale*0.02, scale*0.02); rightKnee = rightElbow + Offset(scale*0.02, scale*0.02); leftAnkle = leftKnee + Offset(-scale*0.02, -scale*0.05); rightAnkle = rightKnee + Offset(scale*0.02, -scale*0.05); }
    } else if (p.contains('extended side angle')) {
      if (stepIndex >= 1) { leftAnkle = leftAnkle + Offset(-scale*0.2, 0); rightAnkle = rightAnkle + Offset(scale*0.1, 0); leftKnee = leftKnee + Offset(-scale*0.12, -scale*0.06); }
      if (stepIndex >= 3) { leftWrist = leftAnkle + Offset(-scale*0.05, -scale*0.05); leftElbow = leftHip + Offset(-scale*0.08, scale*0.04); rightWrist = head + Offset(scale*0.1, -scale*0.12); rightElbow = rightShoulder + Offset(scale*0.12, -scale*0.1); }
    } else if (p.contains('garland')) {
      leftKnee = leftKnee + Offset(-scale*0.18, -scale*0.15); rightKnee = rightKnee + Offset(scale*0.18, -scale*0.15);
      leftAnkle = leftAnkle + Offset(-scale*0.12, -scale*0.25); rightAnkle = rightAnkle + Offset(scale*0.12, -scale*0.25);
      leftHip = leftHip + Offset(-scale*0.04, scale*0.1); rightHip = rightHip + Offset(scale*0.04, scale*0.1);
    } else if (p.contains('warrior iii') || p.contains('warrior3')) {
      if (stepIndex >= 2) { rightKnee = rightHip + Offset(scale*0.2, -scale*0.02); rightAnkle = rightHip + Offset(scale*0.45, -scale*0.02); leftKnee = leftKnee + Offset(0, -scale*0.08); }
      if (stepIndex >= 3) { leftWrist = head + Offset(-scale*0.1, -scale*0.02); rightWrist = head + Offset(scale*0.5, -scale*0.02); leftElbow = leftShoulder + Offset(-scale*0.15, -scale*0.02); rightElbow = rightShoulder + Offset(scale*0.2, -scale*0.02); }
    }

    // ── SITTING / FLOOR POSES ────────────────────────────────────────────────
    else if (p.contains('lotus') || p.contains('butterfly')) {
      // Cross-legged with hands on knees
      if (stepIndex >= 1) { leftWrist = leftKnee + Offset(scale*0.02, -scale*0.02); rightWrist = rightKnee + Offset(-scale*0.02, -scale*0.02); leftElbow = leftHip + Offset(-scale*0.12, scale*0.04); rightElbow = rightHip + Offset(scale*0.12, scale*0.04); }
      if (p.contains('butterfly') && stepIndex >= 2) { leftKnee = leftKnee + Offset(0, -scale*0.06); rightKnee = rightKnee + Offset(0, -scale*0.06); }
    } else if (p.contains('child')) {
      // Fold forward, arms extended ahead
      head = neck + Offset(0, scale*0.15);
      if (stepIndex >= 2) { leftWrist = leftWrist + Offset(-scale*0.15, scale*0.2); rightWrist = rightWrist + Offset(scale*0.15, scale*0.2); leftElbow = leftShoulder + Offset(-scale*0.1, scale*0.1); rightElbow = rightShoulder + Offset(scale*0.1, scale*0.1); }
    } else if (p.contains('cat') || p.contains('cow')) {
      // On all fours – shift to hands-and-knees
      leftWrist = leftHip + Offset(-scale*0.35, -scale*0.15); rightWrist = rightHip + Offset(scale*0.35, -scale*0.15);
      leftElbow = leftShoulder + Offset(-scale*0.18, scale*0.12); rightElbow = rightShoulder + Offset(scale*0.18, scale*0.12);
      leftKnee = leftHip + Offset(scale*0.02, scale*0.22); rightKnee = rightHip + Offset(-scale*0.02, scale*0.22);
      leftAnkle = leftKnee + Offset(scale*0.04, scale*0.1); rightAnkle = rightKnee + Offset(-scale*0.04, scale*0.1);
      if (stepIndex >= 1 && p.contains('cow')) { head = head + Offset(0, -scale*0.08); }
      if (stepIndex >= 1 && p.contains('cat')) { head = head + Offset(0, scale*0.08); }
    } else if (p.contains('boat')) {
      // V-shape – torso leaned back, legs raised
      if (stepIndex >= 1) { leftKnee = leftHip + Offset(-scale*0.05, -scale*0.2); rightKnee = rightHip + Offset(scale*0.05, -scale*0.2); leftAnkle = leftKnee + Offset(-scale*0.05, -scale*0.2); rightAnkle = rightKnee + Offset(scale*0.05, -scale*0.2); }
      if (stepIndex >= 2) { leftWrist = leftKnee + Offset(-scale*0.02, -scale*0.15); rightWrist = rightKnee + Offset(scale*0.02, -scale*0.15); leftElbow = leftShoulder + Offset(-scale*0.08, scale*0.1); rightElbow = rightShoulder + Offset(scale*0.08, scale*0.1); }
    } else if (p.contains('pigeon')) {
      leftKnee = leftHip + Offset(-scale*0.2, scale*0.18); leftAnkle = leftKnee + Offset(scale*0.15, scale*0.08);
      rightKnee = rightHip + Offset(scale*0.04, scale*0.3); rightAnkle = rightKnee + Offset(scale*0.04, scale*0.12);
      if (stepIndex >= 2) { head = head + Offset(0, scale*0.1); leftWrist = leftAnkle + Offset(-scale*0.1, scale*0.04); rightWrist = neck + Offset(scale*0.1, scale*0.04); }
    } else if (p.contains('fish')) {
      head = head + Offset(0, scale*0.08); // Head tilted back
      if (stepIndex >= 2) { leftWrist = leftHip + Offset(-scale*0.05, scale*0.02); rightWrist = rightHip + Offset(scale*0.05, scale*0.02); }
    } else if (p.contains('frog')) {
      leftKnee = leftHip + Offset(-scale*0.28, scale*0.05); rightKnee = rightHip + Offset(scale*0.28, scale*0.05);
      leftAnkle = leftKnee + Offset(0, scale*0.18); rightAnkle = rightKnee + Offset(0, scale*0.18);
    } else if (p.contains('deep breath') || p.contains('anulom') || p.contains('kapalbhati') || p.contains('bhramari') || p.contains('lion') || p.contains('neck') || p.contains('wrist') || p.contains('shoulder roll') || p.contains('chair twist')) {
      // Seated meditation / breathing – wrists rest on knees, spine tall
      leftWrist = leftKnee + Offset(scale*0.02, -scale*0.02); rightWrist = rightKnee + Offset(-scale*0.02, -scale*0.02);
      leftElbow = leftHip + Offset(-scale*0.12, scale*0.02); rightElbow = rightHip + Offset(scale*0.12, scale*0.02);
      if (stepIndex >= 1 && p.contains('anulom')) { rightWrist = neck + Offset(scale*0.04, -scale*0.02); rightElbow = rightShoulder + Offset(scale*0.06, scale*0.04); }
    }

    // ── LYING / PRONE POSES ──────────────────────────────────────────────────
    else if (p.contains('cobra')) {
      if (stepIndex >= 2) { head = head + Offset(0, -scale*0.12); neck = neck + Offset(0, -scale*0.06); leftShoulder = leftShoulder + Offset(0, -scale*0.04); rightShoulder = rightShoulder + Offset(0, -scale*0.04); }
    } else if (p.contains('bow')) {
      if (stepIndex >= 2) { head = head + Offset(0, -scale*0.1); leftAnkle = leftAnkle + Offset(0, -scale*0.15); rightAnkle = rightAnkle + Offset(0, -scale*0.15); leftWrist = leftAnkle; rightWrist = rightAnkle; leftKnee = leftKnee + Offset(0, -scale*0.12); rightKnee = rightKnee + Offset(0, -scale*0.12); }
    } else if (p.contains('bridge')) {
      // Lying on back, hips raised
      if (stepIndex >= 2) { leftHip = leftHip + Offset(0, -scale*0.15); rightHip = rightHip + Offset(0, -scale*0.15); leftKnee = leftKnee + Offset(0, -scale*0.1); rightKnee = rightKnee + Offset(0, -scale*0.1); }
    } else if (p.contains('plank') || p.contains('chaturanga')) {
      // Plank – near horizontal, arms supporting
      if (stepIndex >= 1 && p.contains('chaturanga')) { leftElbow = leftElbow + Offset(0, scale*0.06); rightElbow = rightElbow + Offset(0, scale*0.06); }
    } else if (p.contains('side plank')) {
      // Rotated – stack side on
      leftAnkle = rightAnkle + Offset(-scale*0.02, -scale*0.04); leftKnee = rightKnee + Offset(-scale*0.02, -scale*0.04);
      rightWrist = rightWrist + Offset(0, -scale*0.18); rightElbow = rightShoulder + Offset(scale*0.04, scale*0.06);
    } else if (p.contains('downward')) {
      // Inverted V – hands & feet on ground
      head = neck + Offset(-scale*0.04, scale*0.08);
      leftWrist = leftWrist + Offset(-scale*0.18, scale*0.25); rightWrist = rightWrist + Offset(scale*0.18, scale*0.25);
      leftElbow = leftShoulder + Offset(-scale*0.1, scale*0.12); rightElbow = rightShoulder + Offset(scale*0.1, scale*0.12);
      leftAnkle = leftAnkle + Offset(-scale*0.1, 0); rightAnkle = rightAnkle + Offset(scale*0.1, 0);
    } else if (p.contains('dolphin')) {
      head = neck + Offset(-scale*0.02, scale*0.06);
      leftWrist = leftWrist + Offset(-scale*0.12, scale*0.2); rightWrist = rightWrist + Offset(scale*0.12, scale*0.2);
      leftElbow = leftShoulder + Offset(-scale*0.08, scale*0.16); rightElbow = rightShoulder + Offset(scale*0.08, scale*0.16);
    } else if (p.contains('savasana')) {
      // Completely relaxed – arms slightly apart
      leftWrist = leftHip + Offset(-scale*0.25, scale*0.04); rightWrist = rightHip + Offset(scale*0.25, scale*0.04);
      leftElbow = leftShoulder + Offset(-scale*0.1, scale*0.04); rightElbow = rightShoulder + Offset(scale*0.1, scale*0.04);
    } else if (p.contains('surya')) {
      // Sun Salutation – changes heavily by step
      if (stepIndex == 0) { leftWrist = head + Offset(-scale*0.06, -scale*0.12); rightWrist = head + Offset(scale*0.06, -scale*0.12); }
      if (stepIndex == 1) { head = head + Offset(0, -scale*0.06); }
      if (stepIndex >= 3) { leftAnkle = leftAnkle + Offset(-scale*0.15, 0); rightAnkle = rightAnkle + Offset(scale*0.15, 0); }
    }

    // Helper function to draw glowing sci-fi bones
    void drawGlowingLine(Offset p1, Offset p2) {
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, corePaint);
    }

    // --- DRAW SKELETON BONES ---
    // Head circle
    canvas.drawCircle(head, scale * 0.08, glowPaint);
    canvas.drawCircle(head, scale * 0.08, corePaint);
    canvas.drawCircle(head, scale * 0.08, jointGlowPaint);
    
    // Neck to Spine/Hips
    drawGlowingLine(neck, (leftHip + rightHip) / 2);
    
    // Shoulders
    drawGlowingLine(leftShoulder, rightShoulder);
    drawGlowingLine(neck, leftShoulder);
    drawGlowingLine(neck, rightShoulder);
    
    // Arms
    drawGlowingLine(leftShoulder, leftElbow);
    drawGlowingLine(leftElbow, leftWrist);
    drawGlowingLine(rightShoulder, rightElbow);
    drawGlowingLine(rightElbow, rightWrist);
    
    // Hips
    drawGlowingLine(leftHip, rightHip);
    
    // Legs
    drawGlowingLine(leftHip, leftKnee);
    drawGlowingLine(leftKnee, leftAnkle);
    drawGlowingLine(rightHip, rightKnee);
    drawGlowingLine(rightKnee, rightAnkle);

    // --- DRAW JOINTS AS HIGH-VISIBILITY GLOWING DOTS ---
    final List<Offset> joints = [
      head, neck, leftShoulder, rightShoulder, leftElbow, rightElbow,
      leftWrist, rightWrist, leftHip, rightHip, leftKnee, rightKnee,
      leftAnkle, rightAnkle
    ];
    for (var joint in joints) {
      canvas.drawCircle(joint, 9.0, jointGlowPaint);
      canvas.drawCircle(joint, 5.0, jointCorePaint);
    }
  }

  @override
  bool shouldRepaint(TargetSkeletonPainter old) => 
      old.stepIndex != stepIndex || old.poseName != poseName || old.steps != steps;
}
