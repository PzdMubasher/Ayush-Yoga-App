import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void> _cameraOperationChain = Future.value();
  bool _isInitializingCamera = false;
  bool _isProcessing = false;
  List<Pose> _poses = [];
  String _currentStatus = "Getting ready...";
  late String _targetPoseName;
  double _accuracy = 0.0;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  
   late PoseDetector _poseDetector;
  final FlutterTts _tts = FlutterTts();
  String? _lastTTSLanguage;
  Timer? _ttsTimer;
  Timer? _sessionTimer;
  int _secondsRemaining = 0;
  int _prepCountdown = 3;
  bool _isPrepping = false;
  bool _showBackgroundGuide = true;
  bool _isCoachingCollapsed = false;
  bool _showOnboardingGuide = true;
  InputImageRotation? _currentRotation;
  Size? _imageSize;
  
  List<dynamic> _steps = [];
  int _currentStepIndex = 0;
  DateTime? _stepStartTime;
  int _errorFrameCount = 0;
  String? _lastSpokenMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _targetPoseName = widget.pose.name;
    _secondsRemaining = widget.durationMins * 60;
    _initializePoseDetector();
    _initializeCamera();
    _setupScreen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _sessionTimer?.cancel();
      _ttsTimer?.cancel();
      try {
        _tts.stop();
      } catch (e) {
        debugPrint("Error stopping TTS on pause: $e");
      }
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      if (_secondsRemaining > 0 && !_isPrepping && !_showOnboardingGuide) {
        _startSessionTimer();
      }
    }
  }

  Future<void> _setupScreen() async {
    await _initializeTTS();
    await _loadPoseRules();
    
    if (!mounted) return;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _speakInstruction(langProvider.t('setup_instructions'));
  }

  void _startPrepCountdown() {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    _speakInstruction(langProvider.t('get_ready_countdown'));
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepCountdown > 1) {
        setState(() => _prepCountdown--);
      } else {
        timer.cancel();
        setState(() => _isPrepping = false);
        _startSessionTimer();
        String initialMsg = langProvider.t('go_msg');
        if (_steps.isNotEmpty && _steps[0]['instruction'] != null) {
          initialMsg += langProvider.translateDynamic(_steps[0]['instruction'].toString());
        }
        _speakInstruction(initialMsg);
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() { 
      _currentStatus = langProvider.t('times_up_status'); 
      _accuracy = 1.0; 
      _currentStepIndex = _steps.length; // Stop processing steps
    });
    _speakInstruction(langProvider.t('session_complete_speech'));
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
    final int step = _currentStepIndex;

    // ── Determine the starting position image for early steps ──────────────
    String floorPrep = 'assets/images/lotus_pose.png';
    String lyingPrep = 'assets/images/savasana.png';
    String standingPrep = 'assets/images/mountain_step1.png';
    String tablePrep = 'assets/images/plank_step1.png';
    
    if (pn.contains('neck')) {
      return step == 0 ? floorPrep : 'assets/images/neck_stretch.png';
    }
    if (pn.contains('shoulder')) {
      return step == 0 ? standingPrep : 'assets/images/shoulder_rolls.png';
    }
    if (pn.contains('twist')) {
      return step == 0 ? floorPrep : 'assets/images/chair_twist.png';
    }
    if (pn.contains('wrist')) {
      return step == 0 ? floorPrep : 'assets/images/wrist_stretch.png';
    }
    if (pn.contains('lion')) {
      return step <= 1 ? 'assets/images/child_step1.png' : 'assets/images/lion_breath.png';
    }

    // Breathing & Sitting Stretches
    if (pn.contains('breathing') || pn.contains('anulom') || pn.contains('kapalbhati')) {
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
    
    // Warrior III has 'warrior ii' as a substring, so we must check it before Warrior II!
    if (pn.contains('warrior iii')) {
      return step == 0 ? standingPrep : 'assets/images/warrior3_pose.png';
    }
    if (pn.contains('warrior i') && !pn.contains('ii')) {
      return step <= 1 ? 'assets/images/warrior1_step1.png' : 'assets/images/warrior1_step2.png';
    }
    if (pn.contains('warrior ii')) {
      return step <= 1 ? 'assets/images/warrior1_step1.png' : 'assets/images/warrior_pose.png';
    }
    if (pn.contains('triangle') || pn.contains('extended side') || pn.contains('half moon') || pn.contains('goddess')) {
      // Extended Side Angle and Half Moon Pose have only 3 steps total (0, 1, 2)
      if (pn.contains('extended') || pn.contains('half')) {
        if (step == 0) {
          return pn.contains('extended') ? 'assets/images/warrior1_step1.png' : 'assets/images/triangle_pose.png';
        }
        return pn.contains('extended') ? 'assets/images/extended_side_angle.png' : 'assets/images/half_moon.png';
      }
      
      // Goddess Pose: Step 0 is wide stance, steps 1+ are squatting
      if (pn.contains('goddess')) {
        return step == 0 ? 'assets/images/warrior1_step1.png' : 'assets/images/goddess_pose.png';
      }

      // Triangle Pose (6 steps)
      if (step == 0) return standingPrep;
      if (step <= 2) return 'assets/images/warrior1_step1.png';
      return 'assets/images/triangle_pose.png';
    }
    if (pn.contains('chair')) {
      return step == 0 ? standingPrep : (step == 1 ? 'assets/images/mountain_step2.png' : 'assets/images/chair_pose.png');
    }
    if (pn.contains('plank') && !pn.contains('side')) {
      return step == 0 ? tablePrep : (step == 1 ? 'assets/images/plank_step2.png' : 'assets/images/plank_pose.png');
    }
    if (pn.contains('side plank')) {
      return step == 0 ? 'assets/images/plank_pose.png' : 'assets/images/side_plank.png';
    }
    if (pn.contains('chaturanga')) {
      return step == 0 ? 'assets/images/plank_pose.png' : 'assets/images/chaturanga.png';
    }
    if (pn.contains('cobra')) {
      return step <= 1 ? 'assets/images/cobra_step1.png' : 'assets/images/cobra_pose.png';
    }
    if (pn.contains('bow')) {
      return step <= 2 ? 'assets/images/bow_step1.png' : 'assets/images/bow_pose.png';
    }
    if (pn.contains('bridge')) {
      return step <= 2 ? 'assets/images/bridge_step1.png' : 'assets/images/bridge_pose.png';
    }
    if (pn.contains('fish')) {
      return step == 0 ? lyingPrep : 'assets/images/fish_pose.png';
    }
    if (pn.contains('child')) {
      return step == 0 ? 'assets/images/child_step1.png' : 'assets/images/child_pose.png';
    }
    if (pn.contains('camel')) {
      return step <= 1 ? 'assets/images/child_step1.png' : 'assets/images/camel_pose.png';
    }
    if (pn.contains('downward')) {
      return step == 0 ? tablePrep : (step == 1 ? 'assets/images/downward_step1.png' : 'assets/images/downward_dog.png');
    }
    if (pn.contains('dolphin')) {
      return step == 0 ? tablePrep : 'assets/images/dolphin_pose.png';
    }
    if (pn.contains('pigeon')) {
      return step == 0 ? tablePrep : 'assets/images/pigeon_pose.png';
    }
    if (pn.contains('cat') || pn.contains('cow')) {
      return step == 0 ? tablePrep : 'assets/images/cat_cow.png';
    }
    if (pn.contains('frog')) {
      return step == 0 ? 'assets/images/child_step1.png' : 'assets/images/frog_pose.png';
    }
    if (pn.contains('crow')) {
      return step == 0 ? tablePrep : 'assets/images/crow_pose.png';
    }
    if (pn.contains('surya')) {
      if (step == 0) return standingPrep;
      if (step == 1) return 'assets/images/mountain_step2.png';
      if (step == 2) return 'assets/images/forward_bend.png';
      if (step == 3) return 'assets/images/warrior1_step1.png';
      if (step == 4) return 'assets/images/plank_pose.png';
      if (step == 5) return 'assets/images/chaturanga.png';
      if (step == 6) return 'assets/images/cobra_pose.png';
      if (step == 7) return 'assets/images/downward_dog.png';
      if (step == 8) return 'assets/images/warrior1_step1.png';
      if (step == 9) return 'assets/images/forward_bend.png';
      if (step == 10) return 'assets/images/mountain_step2.png';
      return standingPrep;
    }
    if (pn.contains('eagle')) {
      return step <= 1 ? standingPrep : 'assets/images/eagle_pose.png';
    }
    if (pn.contains('garland')) {
      return 'assets/images/garland_pose.png';
    }
    if (pn.contains('boat')) {
      return step <= 1 ? floorPrep : 'assets/images/boat_pose.png';
    }
    if (pn.contains('butterfly')) {
      return step <= 1 ? floorPrep : 'assets/images/butterfly_pose.png';
    }
    
    // Step-wise guide images for the 21 new poses
    if (pn.contains('reverse warrior')) {
      return step == 0 ? 'assets/images/warrior1_step1.png' : 'assets/images/reverse_warrior.png';
    }
    if (pn.contains('dancer')) {
      return step == 0 ? standingPrep : 'assets/images/dancer_pose.png';
    }
    if (pn.contains('handstand')) {
      return step == 0 ? tablePrep : 'assets/images/handstand.png';
    }
    if (pn.contains('headstand')) {
      return step == 0 ? tablePrep : 'assets/images/headstand.png';
    }
    if (pn.contains('wheel')) {
      return step == 0 ? lyingPrep : 'assets/images/wheel_pose.png';
    }
    if (pn.contains('hero')) {
      return step == 0 ? floorPrep : 'assets/images/hero_pose.png';
    }
    if (pn.contains('seated forward bend')) {
      return step == 0 ? floorPrep : 'assets/images/forward_bend.png';
    }
    if (pn.contains('happy baby')) {
      return step == 0 ? lyingPrep : 'assets/images/happy_baby_pose.png';
    }
    if (pn.contains('locust')) {
      return step == 0 ? 'assets/images/cobra_step1.png' : 'assets/images/locust_pose.png';
    }
    if (pn.contains('puppy')) {
      return step == 0 ? 'assets/images/child_step1.png' : 'assets/images/puppy_pose.png';
    }
    if (pn.contains('firefly')) {
      if (step == 0) return 'assets/images/garland_pose.png';
      if (step == 1) return tablePrep;
      return 'assets/images/firefly_pose.png';
    }
    if (pn.contains('peacock')) {
      if (step == 0) return tablePrep;
      if (step == 1) return 'assets/images/plank_step2.png';
      return 'assets/images/peacock_pose.png';
    }
    if (pn.contains('eight angle')) {
      if (step == 0) return floorPrep;
      if (step == 1) return 'assets/images/butterfly_pose.png';
      return 'assets/images/eight_angle_pose.png';
    }
    if (pn.contains('side crow')) {
      if (step == 0) return 'assets/images/garland_pose.png';
      if (step == 1) return 'assets/images/chair_twist.png';
      if (step == 2) return tablePrep;
      return 'assets/images/side_crow_pose.png';
    }
    if (pn.contains('flying pigeon')) {
      if (step == 0) return standingPrep;
      if (step == 1) return 'assets/images/tree_step1.png';
      if (step == 2) return tablePrep;
      return 'assets/images/flying_pigeon_pose.png';
    }
    if (pn.contains('scorpion')) {
      if (step == 0) return tablePrep;
      if (step == 1) return 'assets/images/dolphin_pose.png';
      if (step == 2) return 'assets/images/bridge_step1.png';
      return 'assets/images/scorpion_pose.png';
    }
    if (pn.contains('forearm stand')) {
      if (step == 0) return tablePrep;
      return 'assets/images/forearm_stand.png';
    }
    if (pn.contains('lizard')) {
      if (step == 0) return 'assets/images/warrior1_step1.png';
      if (step == 1) return 'assets/images/cobra_step1.png';
      return 'assets/images/lizard_pose.png';
    }
    if (pn.contains('dragon')) {
      if (step == 0) return 'assets/images/warrior1_step1.png';
      if (step == 1) return 'assets/images/warrior1_step2.png';
      return 'assets/images/dragon_pose.png';
    }
    if (pn.contains('compass')) {
      if (step == 0) return floorPrep;
      if (step == 1) return 'assets/images/butterfly_pose.png';
      return 'assets/images/compass_pose.png';
    }
    if (pn.contains('split')) {
      if (step == 0) return 'assets/images/warrior1_step1.png';
      return 'assets/images/split_pose.png';
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
        label = langProvider.t('focus_arms');
      } else if (joint.contains('knee') || joint.contains('hip') || joint.contains('leg')) {
        align = const Alignment(0.0, 0.4); // Lower body / legs area
        label = langProvider.t('focus_legs');
      } else if (joint.contains('ankle') || joint.contains('foot') || joint.contains('feet')) {
        align = const Alignment(0.0, 0.7); // Foot area
        label = langProvider.t('focus_feet');
      } else if (joint.contains('spine') || joint.contains('back') || joint.contains('chest')) {
        align = const Alignment(0.0, 0.0); // Spine / Core
        label = langProvider.t('focus_posture');
      } else {
        continue;
      }
      
      highlights.add(
        PulsingFocusHighlight(
          key: ValueKey("${_currentStepIndex}_$joint"),
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
    await _applyTTSLanguage(langProvider.currentLanguage);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Always re-apply language before speaking to prevent TTS engine resets
  Future<void> _applyTTSLanguage(String lang) async {
    if (_lastTTSLanguage == lang) return;
    if (lang == 'hi') {
      await _tts.setLanguage("hi-IN");
    } else if (lang == 'te') {
      await _tts.setLanguage("te-IN");
    } else {
      await _tts.setLanguage("en-US");
    }
    _lastTTSLanguage = lang;
  }

  Future<void> _initializeCamera() {
    _cameraOperationChain = _cameraOperationChain.then((_) async {
      if (_isInitializingCamera) return;
      _isInitializingCamera = true;
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          debugPrint("No cameras available");
          return;
        }
        final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
        final controller = CameraController(
          front,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );
        _controller = controller;
        await controller.initialize();
        if (!mounted) {
          _controller = null;
          await controller.dispose();
          return;
        }
        setState(() {});
        // Let the camera driver fully stabilise before capturing any frame.
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) {
          _controller = null;
          await controller.dispose();
          return;
        }
        if (_controller == controller) {
          await controller.startImageStream(_processCameraImage);
        }
      } catch (e) {
        debugPrint("Camera Error: $e");
      } finally {
        _isInitializingCamera = false;
      }
    });
    return _cameraOperationChain;
  }

  Future<void> _disposeCamera() {
    _cameraOperationChain = _cameraOperationChain.then((_) async {
      final CameraController? cameraController = _controller;
      _controller = null;
      if (cameraController != null) {
        try {
          if (cameraController.value.isStreamingImages) {
            await cameraController.stopImageStream();
          }
        } catch (e) {
          debugPrint("Error stopping image stream: $e");
        }
        try {
          await cameraController.dispose();
        } catch (e) {
          debugPrint("Error disposing camera controller: $e");
        }
      }
    });
    return _cameraOperationChain;
  }

  DateTime? _lastProcessedTime;

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = (width * height / 2).toInt();
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    // 1. Copy Y Plane (Luminance) row by row to strip padding
    final int yRowStride = yPlane.bytesPerRow;
    if (yRowStride == width) {
      nv21.setRange(0, ySize, yBytes);
    } else {
      for (int r = 0; r < height; r++) {
        nv21.setRange(r * width, (r + 1) * width, yBytes, r * yRowStride);
      }
    }

    // 2. Interleave U and V planes into VUVUVU...
    final int vRowStride = vPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    if (vPixelStride == 2) {
      // On many Android devices, the U and V planes are already interleaved,
      // where vPlane.bytes contains V and U interleaved (e.g. V U V U ...).
      // We can copy row-by-row directly from vPlane.bytes.
      for (int r = 0; r < height ~/ 2; r++) {
        final int srcOffset = r * vRowStride;
        final int destOffset = ySize + r * width;
        if (srcOffset + width <= vBytes.length) {
          nv21.setRange(destOffset, destOffset + width, vBytes, srcOffset);
        } else {
          final int available = vBytes.length - srcOffset;
          if (available > 0) {
            nv21.setRange(destOffset, destOffset + available, vBytes, srcOffset);
          }
        }
      }
    } else {
      // Fallback: If pixelStride is 1 (fully planar YUV), manually interleave U and V
      int outIndex = ySize;
      for (int r = 0; r < height ~/ 2; r++) {
        final int vRowStart = r * vRowStride;
        final int uRowStart = r * uRowStride;
        for (int c = 0; c < width ~/ 2; c++) {
          nv21[outIndex++] = vBytes[vRowStart + c];
          nv21[outIndex++] = uBytes[uRowStart + c];
        }
      }
    }

    return nv21;
  }

  void _processCameraImage(CameraImage image) {
    if (!mounted) return;
    if (_isProcessing || _steps.isEmpty || _isPrepping || _showOnboardingGuide) {
      return;
    }

    final now = DateTime.now();
    if (_lastProcessedTime != null && 
        now.difference(_lastProcessedTime!).inMilliseconds < 150) {
      return;
    }

    if (image.planes.isEmpty) return;

    _lastProcessedTime = now;
    _isProcessing = true;

    try {
      final int width = image.width;
      final int height = image.height;
      final int sensorOrientation = _controller?.description.sensorOrientation ?? 0;
      
      final Uint8List bytes;
      if (Platform.isAndroid) {
        bytes = _convertYUV420ToNV21(image);
      } else {
        bytes = image.planes[0].bytes;
      }

      final DeviceOrientation deviceOrientation = _controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp;
      final int deviceRotationDegrees = _orientations[deviceOrientation] ?? 0;
      int rotationDegrees = sensorOrientation;
      if (_controller?.description.lensDirection == CameraLensDirection.front) {
        rotationDegrees = (sensorOrientation + deviceRotationDegrees) % 360;
      } else {
        rotationDegrees = (sensorOrientation - deviceRotationDegrees + 360) % 360;
      }
      
      final InputImageRotation rotation = InputImageRotationValue.fromRawValue(rotationDegrees) ?? InputImageRotation.rotation90deg;
      final InputImageFormat format = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

      final InputImage inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: Platform.isAndroid ? width : image.planes[0].bytesPerRow,
        ),
      );
      _runMlKitDetection(inputImage);
    } catch (e) {
      debugPrint('Error copying camera image: $e');
      _isProcessing = false;
    }
  }

  @override
  void dispose() { 
    WidgetsBinding.instance.removeObserver(this);
    _ttsTimer?.cancel(); 
    _sessionTimer?.cancel();
    _isProcessing = false;
    _disposeCamera(); 
    _poseDetector.close(); 
    try {
      _tts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS on dispose: $e");
    }
    super.dispose(); 
  }

  Future<void> _runMlKitDetection(InputImage inputImage) async {
    if (!mounted) { _isProcessing = false; return; }
    try {
      final poses = await _poseDetector.processImage(inputImage);

      if (!mounted) return;
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _poses = poses;
        _currentRotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation90deg;
        _imageSize = inputImage.metadata?.size;
      });

      if (poses.isNotEmpty) {
        if (!_showOnboardingGuide && !_isPrepping) {
          _updateStepProgress(poses.first);
        }
      } else {
        if (!_isPrepping && !_showOnboardingGuide && _currentStepIndex < _steps.length) {
          _stepStartTime = null;
          setState(() {
            _currentStatus = langProvider.t('no_person_detected');
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

  // Obsolete helper _buildInputImageFromSnapshot removed as frames are processed from a single plane directly.

  String _getUnifiedJointKey(String joint) {
    final j = joint.toLowerCase();
    if (j.contains('leg') || j.contains('knee') || j.contains('bent')) {
      return j.startsWith('left') ? 'left_leg' : 'right_leg';
    }
    if (j.contains('arm') || j.contains('elbow')) {
      return j.startsWith('left') ? 'left_arm' : 'right_arm';
    }
    if (j.contains('shoulder')) {
      return j.startsWith('left') ? 'left_shoulder' : 'right_shoulder';
    }
    if (j == 'spine' || j == 'body_line') {
      return 'spine';
    }
    return j;
  }

  String? _getOppositeJointKey(String joint) {
    if (joint.startsWith("left_")) {
      return joint.replaceFirst("left_", "right_");
    } else if (joint.startsWith("right_")) {
      return joint.replaceFirst("right_", "left_");
    }
    return null;
  }

  void _updateStepProgress(Pose pose) {
    if (_currentStepIndex >= _steps.length) return;

    final currentStep = _steps[_currentStepIndex];
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);


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
          _accuracy = 1.0;
          _currentStatus = "🧘 $stepInstruction... ${_formatTime(_secondsRemaining)}";
        });
      } else if (elapsed >= holdSecs) {
        _moveToNextStep();
      } else {
        setState(() {
          _accuracy = 1.0;
          _currentStatus = "🧘 $stepInstruction — ${remaining}s";
        });
      }
      return;
    }

    final lowercasePose = _targetPoseName.toLowerCase();
    final bool isSittingOrGroundPose = 
        lowercasePose.contains("cobra") ||
        lowercasePose.contains("child") ||
        lowercasePose.contains("lotus") ||
        lowercasePose.contains("bridge") ||
        lowercasePose.contains("plank") ||
        lowercasePose.contains("savasana") ||
        lowercasePose.contains("boat") ||
        lowercasePose.contains("butterfly") ||
        lowercasePose.contains("camel") ||
        lowercasePose.contains("crow") ||
        lowercasePose.contains("chaturanga") ||
        lowercasePose.contains("bow") ||
        lowercasePose.contains("pigeon") ||
        lowercasePose.contains("fish") ||
        lowercasePose.contains("frog") ||
        lowercasePose.contains("cat-cow") ||
        lowercasePose.contains("garland") ||
        lowercasePose.contains("breathing") ||
        lowercasePose.contains("anulom") ||
        lowercasePose.contains("kapalbhati") ||
        lowercasePose.contains("bhramari") ||
        lowercasePose.contains("lion") ||
        lowercasePose.contains("handstand") ||
        lowercasePose.contains("headstand") ||
        lowercasePose.contains("wheel") ||
        lowercasePose.contains("hero") ||
        lowercasePose.contains("seated forward") ||
        lowercasePose.contains("happy baby") ||
        lowercasePose.contains("locust") ||
        lowercasePose.contains("puppy") ||
        lowercasePose.contains("firefly") ||
        lowercasePose.contains("peacock") ||
        lowercasePose.contains("eight angle") ||
        lowercasePose.contains("side crow") ||
        lowercasePose.contains("flying pigeon") ||
        lowercasePose.contains("scorpion") ||
        lowercasePose.contains("forearm stand") ||
        lowercasePose.contains("lizard") ||
        lowercasePose.contains("dragon") ||
        lowercasePose.contains("compass") ||
        lowercasePose.contains("split");

    // Accumulate rules from Step 0 → _currentStepIndex (later rules override earlier for same joint)
    final Map<String, Map<String, dynamic>> activeRulesMap = {};
    for (int i = 0; i <= _currentStepIndex; i++) {
      final stepRules = (_steps[i]['rules'] as List<dynamic>);
      for (var rule in stepRules) {
        final rawJoint = rule['joint'] as String;
        final unifiedKey = _getUnifiedJointKey(rawJoint);
        final ruleCopy = Map<String, dynamic>.from(rule);
        // Tag if this rule belongs to the current step
        ruleCopy['isCurrentStepRule'] = (i == _currentStepIndex);
        // Save raw joint name for computation
        ruleCopy['rawJoint'] = rawJoint;

        if (isSittingOrGroundPose) {
          // Dynamically adjust rules that expect straight limbs/spine in a bent/sitting pose
          final double currentMin = (ruleCopy['idealMin'] as num?)?.toDouble() ?? 0.0;
          
          final bool requiresStraightLegs = 
              lowercasePose.contains("plank") ||
              lowercasePose.contains("chaturanga") ||
              lowercasePose.contains("savasana") ||
              lowercasePose.contains("cobra") ||
              lowercasePose.contains("handstand") ||
              lowercasePose.contains("headstand") ||
              lowercasePose.contains("forearm stand") ||
              lowercasePose.contains("peacock") ||
              lowercasePose.contains("split") ||
              lowercasePose.contains("lizard") ||
              lowercasePose.contains("dragon") ||
              lowercasePose.contains("compass") ||
              lowercasePose.contains("locust");

          if (rawJoint.contains("knee") || rawJoint.contains("leg") || rawJoint.contains("ankle")) {
            if (currentMin >= 140.0 && !requiresStraightLegs) {
              // For sitting/ground poses, knees/legs should be bent
              ruleCopy['idealMin'] = 20.0;
              ruleCopy['idealMax'] = 120.0;
              ruleCopy['messageLow'] = 'Bend your knees';
              ruleCopy['messageHigh'] = 'Bend your knees';
            }
          } else if (rawJoint == "spine") {
            if (currentMin >= 150.0) {
              if (lowercasePose.contains("child") ||
                  lowercasePose.contains("cat-cow") ||
                  lowercasePose.contains("crow") ||
                  lowercasePose.contains("pigeon") ||
                  lowercasePose.contains("butterfly") ||
                  lowercasePose.contains("cobra") ||
                  lowercasePose.contains("camel") ||
                  lowercasePose.contains("bow") ||
                  lowercasePose.contains("fish") ||
                  lowercasePose.contains("bridge")) {
                ruleCopy['idealMin'] = 80.0;
                ruleCopy['idealMax'] = 155.0; // allow dynamic arching/curving
                ruleCopy['messageLow'] = 'Arch or curve your back';
                ruleCopy['messageHigh'] = 'Align your back';
              }
            }
          } else if (rawJoint.contains("arm") || rawJoint.contains("elbow")) {
            if (currentMin >= 140.0) {
              if (lowercasePose.contains("child") ||
                  lowercasePose.contains("butterfly") ||
                  lowercasePose.contains("cobra") ||
                  lowercasePose.contains("crow") ||
                  lowercasePose.contains("bow") ||
                  lowercasePose.contains("pigeon") ||
                  lowercasePose.contains("peacock") ||
                  lowercasePose.contains("eight angle") ||
                  lowercasePose.contains("side crow") ||
                  lowercasePose.contains("flying pigeon") ||
                  lowercasePose.contains("scorpion") ||
                  lowercasePose.contains("forearm stand") ||
                  lowercasePose.contains("puppy") ||
                  lowercasePose.contains("happy baby")) {
                ruleCopy['idealMin'] = 20.0;
                ruleCopy['idealMax'] = 140.0;
                ruleCopy['messageLow'] = 'Bend your elbows';
                ruleCopy['messageHigh'] = 'Bend your elbows';
              }
            }
          }
        }

        activeRulesMap[unifiedKey] = ruleCopy;
      }
    }

    // Dynamically filter out impossible or noisy rules for sitting/asymmetrical poses
    if (lowercasePose.contains("lotus")) {
      // Exclude leg/knee/ankle checks once legs are crossed (Step index >= 1)
      if (_currentStepIndex >= 1) {
        activeRulesMap.removeWhere((key, rule) {
          final String joint = rule['rawJoint'].toString().toLowerCase();
          return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle");
        });
      }
      // Exclude arm/elbow checks since hands rest on knees
      activeRulesMap.removeWhere((key, rule) {
        final String joint = rule['rawJoint'].toString().toLowerCase();
        return joint.contains("arm") || joint.contains("elbow");
      });
    } else if (lowercasePose.contains("deep breath") || lowercasePose.contains("breathing")) {
      // Exclude leg/knee/ankle checks (since cross-legged) and arm/elbow checks (since hands rest on knees)
      activeRulesMap.removeWhere((key, rule) {
        final String joint = rule['rawJoint'].toString().toLowerCase();
        return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle") ||
               joint.contains("arm") || joint.contains("elbow");
      });
    } else if (lowercasePose.contains("lion")) {
      // Exclude leg/knee/ankle/arm/elbow checks since kneeling with palms on knees
      activeRulesMap.removeWhere((key, rule) {
        final String joint = rule['rawJoint'].toString().toLowerCase();
        return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle") ||
               joint.contains("arm") || joint.contains("elbow");
      });
    } else if (lowercasePose.contains("butterfly")) {
      // Exclude arm/elbow checks (holding feet) and leg/knee checks (soles together)
      activeRulesMap.removeWhere((key, rule) {
        final String joint = rule['rawJoint'].toString().toLowerCase();
        return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle") ||
               joint.contains("arm") || joint.contains("elbow");
      });
    } else if (lowercasePose.contains("garland")) {
      // Exclude arm/elbow checks in Step 2 (which is index 1, "Prayer Palms")
      if (_currentStepIndex == 1) {
        activeRulesMap.removeWhere((key, rule) {
          final String joint = rule['rawJoint'].toString().toLowerCase();
          return joint.contains("arm") || joint.contains("elbow");
        });
      }
    } else if (lowercasePose.contains("eagle")) {
      // Exclude leg checks in Step 1 (index 0, "Wrap Legs")
      if (_currentStepIndex == 0) {
        activeRulesMap.removeWhere((key, rule) {
          final String joint = rule['rawJoint'].toString().toLowerCase();
          return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle");
        });
      }
      // Exclude arm checks in Step 2 (index 1, "Wrap Arms")
      else if (_currentStepIndex == 1) {
        activeRulesMap.removeWhere((key, rule) {
          final String joint = rule['rawJoint'].toString().toLowerCase();
          return joint.contains("arm") || joint.contains("elbow");
        });
      }
    } else if (lowercasePose.contains("frog")) {
      // Exclude leg and arm checks (wide knees and elbows on floor)
      activeRulesMap.removeWhere((key, rule) {
        final String joint = rule['rawJoint'].toString().toLowerCase();
        return joint.contains("knee") || joint.contains("leg") || joint.contains("ankle") ||
               joint.contains("arm") || joint.contains("elbow");
      });
    } else if (lowercasePose.contains("wrist")) {
      // Compare left and right arm angles and dynamically remove the bent arm's check, keeping only the straight, extended arm's check
      final double? leftArmAngle = _calculateAngle(pose, "left_arm");
      final double? rightArmAngle = _calculateAngle(pose, "right_arm");
      if (leftArmAngle != null && rightArmAngle != null) {
        if (leftArmAngle > rightArmAngle) {
          activeRulesMap.removeWhere((key, rule) => rule['rawJoint'] == "right_arm");
        } else {
          activeRulesMap.removeWhere((key, rule) => rule['rawJoint'] == "left_arm");
        }
      } else if (leftArmAngle != null) {
        activeRulesMap.removeWhere((key, rule) => rule['rawJoint'] == "right_arm");
      } else if (rightArmAngle != null) {
        activeRulesMap.removeWhere((key, rule) => rule['rawJoint'] == "left_arm");
      }
    }

    // If this pose has no trackable rules at all, use a minimum hold timer
    if (activeRulesMap.isEmpty) {
      _stepStartTime ??= DateTime.now();
      final elapsed = DateTime.now().difference(_stepStartTime!).inSeconds;
      final int holdSecs = 6;
      final String stepInstruction = langProvider.translateDynamic(currentStep['instruction'].toString());
      final String holdMsg = langProvider.t('hold_pose');
      if (_currentStepIndex == _steps.length - 1) {
        setState(() { _accuracy = 1.0; _currentStatus = "$holdMsg... ${_formatTime(_secondsRemaining)}"; });
      } else if (elapsed >= holdSecs) {
        _moveToNextStep();
      } else {
        setState(() { _accuracy = 1.0; _currentStatus = "$stepInstruction — ${holdSecs - elapsed}s"; });
      }
      return;
    }

    // Evaluate all accumulated rules against current camera landmarks
    bool allRulesPassed = true;
    int validRulesChecked = 0; // count rules where angle was actually measurable
    String feedback = langProvider.translateDynamic(currentStep['instruction'].toString());

    final String positionMsg = langProvider.t('position_clearly');

    for (var rule in activeRulesMap.values) {
      final String rawJoint = rule['rawJoint'] as String;
      final String unifiedKey = _getUnifiedJointKey(rawJoint);
      double? angle = _calculateAngle(pose, rawJoint);

      // Level tolerance: Beginner gets ±12°, Intermediate ±6°, Advanced ±0°
      double tolerance = 0;
      if (widget.level == "Beginner") tolerance = 12;
      if (widget.level == "Intermediate") tolerance = 6;

      final double minVal = (rule['idealMin'] as num).toDouble() - tolerance;
      final double maxVal = (rule['idealMax'] as num).toDouble() + tolerance;

      // Dynamic side-agnostic check:
      // If the joint is asymmetrical (e.g. only left is checked, but not right),
      // and the current side fails or is null, check if the opposite side passes.
      if (unifiedKey.startsWith("left_") || unifiedKey.startsWith("right_")) {
        final oppositeKey = _getOppositeJointKey(unifiedKey);
        if (oppositeKey != null) {
          // Symmetrical check: if both sides are active in the rules, don't swap.
          final bool isSymmetrical = activeRulesMap.containsKey(oppositeKey);
          if (!isSymmetrical) {
            bool currentPasses = angle != null && angle >= minVal && angle <= maxVal;
            if (!currentPasses) {
              final oppositeRawJoint = rawJoint.startsWith("left")
                  ? rawJoint.replaceFirst("left", "right")
                  : rawJoint.replaceFirst("right", "left");
              double? oppAngle = _calculateAngle(pose, oppositeRawJoint);
              if (oppAngle != null && oppAngle >= minVal && oppAngle <= maxVal) {
                angle = oppAngle; // Swap to the passing opposite side!
              }
            }
          }
        }
      }

      final bool isCurrentStepRule = rule['isCurrentStepRule'] as bool? ?? false;

      if (angle == null) {
        // Enforce current step rules: if a rule from the current step is missing, we fail the progress.
        // Otherwise (for older steps), we continue gracefully.
        // For sitting or ground poses, we bypass failing if the joint is occluded/missing.
        if (isCurrentStepRule && !isSittingOrGroundPose) {
          allRulesPassed = false;
        }
        continue;
      }

      validRulesChecked++;

      if (angle < minVal || angle > maxVal) {
        allRulesPassed = false;
        final String feedbackMsg = angle < minVal
            ? (rule['messageLow'] ?? rule['messageHigh'] ?? currentStep['instruction'])
            : (rule['messageHigh'] ?? rule['messageLow'] ?? currentStep['instruction']);
        feedback = langProvider.translateDynamic(feedbackMsg);
        break;
      }
    }

    // If ZERO rules produced a measurable angle, the body is not visible at all —
    // show 'position yourself' instead of silently passing the step.
    if (validRulesChecked == 0 && activeRulesMap.isNotEmpty) {
      allRulesPassed = false;
      feedback = positionMsg;
    }

    if (allRulesPassed) {
      _errorFrameCount = 0;
      _stepStartTime ??= DateTime.now();
      final duration = DateTime.now().difference(_stepStartTime!).inSeconds;

      // Required hold time: must maintain CORRECT posture for this long before advancing
      int requiredHold = 3;  // Beginner: 3 seconds
      if (widget.level == "Intermediate") requiredHold = 8;
      if (widget.level == "Advanced") requiredHold = 12;

      final String perfectMsg = langProvider.t('perfect_msg');
      final String holdMsg = langProvider.t('hold_for');

      if (_currentStepIndex == _steps.length - 1) {
        setState(() {
          _accuracy = 1.0;
          _currentStatus = "$perfectMsg ${langProvider.t('keep_holding')} ${_formatTime(_secondsRemaining)}";
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
      if (_errorFrameCount >= 5) { // Must be wrong posture for at least ~0.5s before generating voice alert
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
      final perfectWord = langProvider.t('perfect_word');
      final instruction = langProvider.translateDynamic(_steps[_currentStepIndex]['instruction'].toString());
      _applyTTSLanguage(langProvider.currentLanguage).then((_) async {
        try {
          await _tts.stop();
          await _tts.speak('$perfectWord$instruction');
        } catch (e) {
          debugPrint("Error speaking step advance: $e");
        }
      }).catchError((e) {
        debugPrint("Error in step advance speech chain: $e");
      });
    }
  }

  double? _calculateAngle(Pose pose, String joint) {
    final landmarks = pose.landmarks;

    double? getValidAngle(PoseLandmark? p1, PoseLandmark? p2, PoseLandmark? p3, {bool requireUpright = false}) {
      if (p1 == null || p2 == null || p3 == null) return null;
      
      // Using 0.20 threshold allows detection under cover fit and distant users.
      if (p1.likelihood < 0.20 || p2.likelihood < 0.20 || p3.likelihood < 0.20) return null;
      
      // If we require the person to be standing/upright (e.g. spine checks),
      // the shoulder (p1) must be physically above the hip (p2). In ML Kit Y=0 is the top.
      if (requireUpright && p1.y > p2.y) return null;

      return _getAngle(p1, p2, p3);
    }

    if (joint.contains("shoulder")) {
      final h = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
      final s = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
      final e = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
      
      if (s != null && e != null) {
        final instruction = _currentStepIndex < _steps.length 
            ? (_steps[_currentStepIndex]['instruction']?.toString().toLowerCase() ?? '') 
            : '';
        final isRaisingArms = instruction.contains("overhead") || 
                              instruction.contains("upward") || 
                              instruction.contains("upward salute") ||
                              instruction.contains("raise both arms") ||
                              instruction.contains("raise arms overhead") ||
                              instruction.contains("lift both arms") ||
                              (instruction.contains("raise") && instruction.contains("arms") && !instruction.contains("shoulder level"));
        
        if (isRaisingArms && e.y >= s.y) {
          return 0.0; // Fail the check
        }
      }
      return getValidAngle(h, s, e);
    } else if (joint.contains("arm")) {
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
      
      // Inversion check: for inverted poses, hip/knee/ankle must be physically higher than shoulder (ML Kit Y decreases upwards)
      final invertedPoses = ["Handstand", "Headstand", "Forearm Stand", "Scorpion Pose"];
      if (invertedPoses.contains(_targetPoseName)) {
        final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
        final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
        final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
        if (shoulder != null && hip != null) {
          if (hip.y > shoulder.y) return 0.0; // Fail check
          if (knee != null && knee.y > hip.y) return 0.0; // Fail check
        }
      }

      final uprightStandingPoses = [
        "Mountain Pose", "Tree Pose", "Warrior I", "Warrior II", 
        "Chair Pose", "Goddess Pose"
      ];
      bool requireUpright = uprightStandingPoses.contains(_targetPoseName);
      
      final sittingUprightPoses = [
        "Lotus Pose", "Deep Breathing", "Anulom Vilom", "Kapalbhati",
        "Bhramari", "Neck Stretch", "Butterfly Pose", "Chair Twist", "Lion Breath", "Boat Pose",
        "Hero Pose", "Seated Forward Bend", "Compass Pose", "Split Pose", "Eight Angle Pose"
      ];
      
      if (sittingUprightPoses.contains(_targetPoseName)) {
        if (s == null || h == null) return null;
        if (s.likelihood < 0.20 || h.likelihood < 0.20) return null;
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
    _applyTTSLanguage(langProvider.currentLanguage).then((_) async {
      try {
        await _tts.stop();
        await _tts.speak(langProvider.translateDynamic(msg));
      } catch (e) {
        debugPrint("Error in _speakInstruction: $e");
      }
    }).catchError((e) {
      debugPrint("Error in _speakInstruction chain: $e");
    });
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
    _applyTTSLanguage(langProvider.currentLanguage).then((_) async {
      try {
        await _tts.stop();
        await _tts.speak(langProvider.translateDynamic(message));
      } catch (e) {
        debugPrint("Error in _provideVoiceFeedback: $e");
      }
    }).catchError((e) {
      debugPrint("Error in _provideVoiceFeedback chain: $e");
    });
  }

  // Convert a landmark to screen coordinates
  Offset _landmarkToScreen(PoseLandmark lm, Size screenSize) {
    final imgSize = _imageSize ?? _controller?.value.previewSize ?? const Size(720, 480);
    final previewSize = _controller?.value.previewSize ?? const Size(1280, 720);
    final rot = _currentRotation ?? InputImageRotation.rotation270deg;
    final bool isFrontCamera = _controller?.description.lensDirection == CameraLensDirection.front;

    // Dimensions of the raw image frame processed by ML Kit
    final double rawImgW = (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg)
        ? imgSize.height
        : imgSize.width;
    final double rawImgH = (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg)
        ? imgSize.width
        : imgSize.height;

    // Dimensions of the camera preview (the container aspect ratio)
    final double previewW = (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg)
        ? previewSize.height
        : previewSize.width;
    final double previewH = (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg)
        ? previewSize.width
        : previewSize.height;

    // Normalized coordinates of the landmark in the raw image frame [0, 1]
    final double normX = lm.x / rawImgW;
    final double normY = lm.y / rawImgH;

    // Scale preview to cover screen (same as we do for the CameraPreview container)
    final double scale = math.max(screenSize.width / previewW, screenSize.height / previewH);
    final double scaledPreviewW = previewW * scale;
    final double scaledPreviewH = previewH * scale;

    final double dx = (screenSize.width - scaledPreviewW) / 2;
    final double dy = (screenSize.height - scaledPreviewH) / 2;

    // Map normalized coordinates to the scaled preview container
    double x = normX * scaledPreviewW + dx;
    double y = normY * scaledPreviewH + dy;

    if (isFrontCamera) {
      x = screenSize.width - x;
    }

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
          LayoutBuilder(
            builder: (context, constraints) {
              final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
              final previewSize = _controller?.value.previewSize ?? const Size(1280, 720);
              final rot = _currentRotation ?? InputImageRotation.rotation270deg;
              final isPortrait = rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg;
              
              final double previewW = isPortrait ? previewSize.height : previewSize.width;
              final double previewH = isPortrait ? previewSize.width : previewSize.height;
              
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: CameraPreview(_controller!),
                      ),
                    ),

                    // The green target skeleton and background ghost have been removed based on user feedback to ensure the user is perfectly visible.

                    // ── USER'S LIVE SKELETON (detected joints from camera) ─────────
                    if (_poses.isNotEmpty)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SkeletonPainter(
                            pose: _poses.first,
                            widgetSize: widgetSize,
                            landmarkToScreen: _landmarkToScreen,
                            color: poseColor,
                          ),
                        ),
                      ),

                    // ── FOCUS HIGHLIGHT RINGS ─────────────────────────────────────
                    if (_showBackgroundGuide)
                      ..._buildFocusHighlights(langProvider),
                  ],
                ),
              );
            },
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
                  color: Colors.black54, // Sleek semi-transparent dark background for transparent pose contrast
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _showBackgroundGuide ? const Color(0xFF00FF88) : Colors.white24, 
                    width: 2
                  ),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: Stack(
                  children: [
                    // The pose guide image with padding to fit perfectly inside the card
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          _getStepGuideImage(),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
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
            bottom: 16 + MediaQuery.of(context).padding.bottom, left: 16, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accuracy >= 1.0 
                        ? const Color(0xFF00FF88).withOpacity(0.6) 
                        : Colors.white.withOpacity(0.15), 
                      width: 1.5
                    ),
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row: step label + timer + guide toggle + collapse + close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${langProvider.t('step')} ${_currentStepIndex + 1}/${_steps.length}", 
                          style: GoogleFonts.outfit(color: const Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Text(_formatTime(_secondsRemaining), 
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _showBackgroundGuide ? Icons.accessibility_new : Icons.accessibility_new_outlined, 
                              color: _showBackgroundGuide ? const Color(0xFF00FF88) : Colors.white54, 
                              size: 20
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
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              _isCoachingCollapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                              color: Colors.white54, 
                              size: 22
                            ),
                            onPressed: () {
                              setState(() {
                                _isCoachingCollapsed = !_isCoachingCollapsed;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: _isCoachingCollapsed ? "Expand coaching guide" : "Collapse coaching guide",
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20), 
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (_isCoachingCollapsed) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        langProvider.translateDynamic(_currentStatus),
                        style: GoogleFonts.outfit(
                          color: statusColor, 
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),

                    // ── STEPS ROADMAP (horizontal scrollable mini pills) ─────────
                    if (_steps.isNotEmpty)
                      SizedBox(
                        height: 24,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _steps.length,
                          itemBuilder: (ctx, i) {
                            final isDone = i < _currentStepIndex;
                            final isCurrent = i == _currentStepIndex;
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDone
                                  ? const Color(0xFF00FF88).withOpacity(0.2)
                                  : isCurrent
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDone
                                    ? const Color(0xFF00FF88).withOpacity(0.6)
                                    : isCurrent ? Colors.white38 : Colors.white12,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDone) ...[
                                    const Icon(Icons.check, color: Color(0xFF00FF88), size: 10),
                                    const SizedBox(width: 4),
                                  ],
                                  if (isCurrent)
                                    Container(
                                      width: 5, height: 5,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Text(
                                    langProvider.translateDynamic(
                                      _steps[i]['stepName']?.toString() ?? 'Step ${i+1}'
                                    ),
                                    style: GoogleFonts.outfit(
                                      color: isDone
                                        ? const Color(0xFF00FF88)
                                        : isCurrent ? Colors.white : Colors.white30,
                                      fontSize: 10,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ── CURRENT STEP CARD — prominent coaching box ──────────────
                    if (_steps.isNotEmpty && _currentStepIndex < _steps.length)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accuracy >= 1.0
                            ? const Color(0xFF00FF88).withOpacity(0.12)
                            : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accuracy >= 1.0
                              ? const Color(0xFF00FF88).withOpacity(0.5)
                              : Colors.white12,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF88).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.radio_button_checked, color: Color(0xFF00FF88), size: 8),
                                      const SizedBox(width: 4),
                                      Text(
                                        langProvider.translateDynamic(
                                          _steps[_currentStepIndex]['stepName']?.toString() ?? ''
                                        ).toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF00FF88),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (_accuracy >= 1.0)
                                  const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 16),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              langProvider.translateDynamic(_currentStatus),
                              textAlign: TextAlign.left,
                              style: GoogleFonts.outfit(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                            ),
                          ],
                        ),
                      ),

                    // ── NEXT STEP PREVIEW ────────────────────────────────────────
                    if (_steps.isNotEmpty && _currentStepIndex < _steps.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_forward, color: Colors.white30, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              langProvider.t('next'),
                              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                langProvider.translateDynamic(
                                  _steps[_currentStepIndex + 1]['stepName']?.toString() ?? ''
                                ),
                                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
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
                      langProvider.t('get_ready'), 
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
                        langProvider.t('pose_prep'),
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
                        title: langProvider.t('place_phone'),
                        description: langProvider.t('place_phone_desc'),
                      ),
                      _buildOnboardingStep(
                        icon: Icons.lightbulb_outline,
                        title: langProvider.t('ensure_lighting'),
                        description: langProvider.t('ensure_lighting_desc'),
                      ),
                      _buildOnboardingStep(
                        icon: Icons.center_focus_strong,
                        title: langProvider.t('align_image'),
                        description: langProvider.t('align_image_desc'),
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
                              langProvider.t('lets_start'),
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

// Highly optimized CustomPainter for rendering the entire user skeleton in a single pass
class _SkeletonPainter extends CustomPainter {
  final Pose pose;
  final Size widgetSize;
  final Offset Function(PoseLandmark lm, Size screenSize) landmarkToScreen;
  final Color color;

  _SkeletonPainter({
    required this.pose,
    required this.widgetSize,
    required this.landmarkToScreen,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Draw connection lines
    for (final conn in connections) {
      final lm1 = pose.landmarks[conn[0]];
      final lm2 = pose.landmarks[conn[1]];
      if (lm1 != null && lm2 != null && lm1.likelihood >= 0.20 && lm2.likelihood >= 0.20) {
        final p1 = landmarkToScreen(lm1, widgetSize);
        final p2 = landmarkToScreen(lm2, widgetSize);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Paint for white border of the joint dots
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Paint for the joint dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Paint for the glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Draw dots for each landmark
    for (final entry in pose.landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < 0.20) continue;
      final offset = landmarkToScreen(lm, widgetSize);
      
      // Draw glow shadow
      canvas.drawCircle(offset, 6.0, glowPaint);
      // Draw main dot
      canvas.drawCircle(offset, 6.0, dotPaint);
      // Draw border
      canvas.drawCircle(offset, 6.0, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.widgetSize != widgetSize ||
        oldDelegate.color != color;
  }
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


