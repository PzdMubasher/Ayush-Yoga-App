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
  bool _isPrepping = true;
  DateTime? _lastProcessedTime;
  InputImageRotation? _currentRotation;
  Size? _imageSize;
  
  List<dynamic> _steps = [];
  int _currentStepIndex = 0;
  bool _stepCompleted = false;
  DateTime? _stepStartTime;

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
    _startPrepCountdown();
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
      ResolutionPreset.medium, 
      enableAudio: false, 
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888
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
    if (_isProcessing || _steps.isEmpty || _isPrepping) return;

    // THROTTLE: Only process every 500ms (~2 FPS) to prevent GC storm on low-end devices
    final now = DateTime.now();
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 500) {
      return;
    }
    _lastProcessedTime = now;

    _isProcessing = true;
    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) { _isProcessing = false; return; }
      
      final poses = await _poseDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _poses = poses;
          _currentRotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation90deg;
          _imageSize = inputImage.metadata?.size;
        });
        
        if (poses.isNotEmpty) {
          _updateStepProgress(poses.first);
        }
      }
    } catch (e) {
      debugPrint("AI Processing Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format != InputImageFormat.bgra8888) return null;
      if (image.planes.isEmpty) return null;
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
    
    // Android YUV_420_888 -> NV21 conversion
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    
    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: yPlane.bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: yPlane.bytesPerRow,
        ),
      );
    }
    
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    
    final nv21 = Uint8List(width * height * 3 ~/ 2);
    
    if (yPlane.bytesPerRow == width) {
      nv21.setRange(0, width * height, yPlane.bytes);
    } else {
      for (int row = 0; row < height; row++) {
        final srcOffset = row * yPlane.bytesPerRow;
        final dstOffset = row * width;
        if (srcOffset + width <= yPlane.bytes.length) {
          nv21.setRange(dstOffset, dstOffset + width, yPlane.bytes, srcOffset);
        }
      }
    }
    
    int uvIndex = width * height;
    final uvHeight = height ~/ 2;
    
    if (uvPixelStride == 2) {
      if (uvRowStride == width) {
        final uvSize = math.min(vPlane.bytes.length, width * uvHeight);
        nv21.setRange(uvIndex, uvIndex + uvSize, vPlane.bytes);
      } else {
        for (int row = 0; row < uvHeight; row++) {
          final srcOffset = row * uvRowStride;
          final dstOffset = uvIndex + row * width;
          final copyLen = math.min(width, vPlane.bytes.length - srcOffset);
          if (copyLen > 0 && dstOffset + copyLen <= nv21.length) {
            nv21.setRange(dstOffset, dstOffset + copyLen, vPlane.bytes, srcOffset);
          }
        }
      }
    } else {
      final uvWidth = width ~/ 2;
      for (int row = 0; row < uvHeight; row++) {
        for (int col = 0; col < uvWidth; col++) {
          final srcIndex = row * uvRowStride + col * uvPixelStride;
          if (srcIndex < vPlane.bytes.length && srcIndex < uPlane.bytes.length && uvIndex + 1 < nv21.length) {
            nv21[uvIndex++] = vPlane.bytes[srcIndex];
            nv21[uvIndex++] = uPlane.bytes[srcIndex];
          }
        }
      }
    }
    
    return InputImage.fromBytes(
      bytes: nv21, 
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()), 
        rotation: rotation, 
        format: InputImageFormat.nv21, 
        bytesPerRow: width
      )
    );
  }

  void _updateStepProgress(Pose pose) {
    if (_currentStepIndex >= _steps.length) return;

    final currentStep = _steps[_currentStepIndex];
    final currentRules = currentStep['rules'] as List<dynamic>;
    
    // If no rules in the entire pose, just show the instruction (fallback poses)
    if (_steps.every((s) => (s['rules'] as List).isEmpty)) {
      setState(() { 
        _accuracy = 0.7; 
        _currentStatus = "Great! Hold the pose... ${_formatTime(_secondsRemaining)}"; 
      });
      return;
    }
    
    // Accumulate all rules from Step 0 to _currentStepIndex.
    // Newer rules for the same joint overwrite older rules to avoid contradictions (e.g. Cobra Pose).
    final Map<String, Map<String, dynamic>> activeRulesMap = {};
    for (int i = 0; i <= _currentStepIndex; i++) {
      final step = _steps[i];
      final stepRules = step['rules'] as List<dynamic>;
      for (var rule in stepRules) {
        final joint = rule['joint'] as String;
        activeRulesMap[joint] = Map<String, dynamic>.from(rule);
      }
    }
    final activeRules = activeRulesMap.values.toList();
    
    bool allRulesPassed = true;
    String feedback = currentStep['instruction'];

    for (var rule in activeRules) {
      double? angle = _calculateAngle(pose, rule['joint']);
      
      // Level adjustments (stricter for better accuracy)
      double tolerance = 0;
      if (widget.level == "Beginner") tolerance = 10;
      if (widget.level == "Intermediate") tolerance = 5;

      if (angle == null) {
        allRulesPassed = false;
        feedback = "Position yourself clearly in the camera view";
        break;
      } else if (angle < (rule['idealMin'] - tolerance) || angle > (rule['idealMax'] + tolerance)) {
        allRulesPassed = false;
        feedback = rule['messageLow'] ?? rule['messageHigh'] ?? feedback;
        break;
      }
    }

    if (allRulesPassed) {
      _stepStartTime ??= DateTime.now();
      final duration = DateTime.now().difference(_stepStartTime!).inSeconds;
      
      int requiredHold = 3;
      if (widget.level == "Intermediate") requiredHold = 7;
      if (widget.level == "Advanced") requiredHold = 15;

      if (_currentStepIndex == _steps.length - 1) {
        // Final Step: Don't advance, just hold until session timer ends!
        setState(() { _accuracy = 1.0; _currentStatus = "✅ Perfect! Keep holding... ${_formatTime(_secondsRemaining)}"; });
      } else if (duration >= requiredHold) {
        _moveToNextStep();
      } else {
        setState(() { _accuracy = 1.0; _currentStatus = "✅ Perfect! Hold... ${requiredHold - duration}s"; });
      }
    } else {
      _stepStartTime = null;
      setState(() { _accuracy = 0.4; _currentStatus = feedback; });
      _provideVoiceFeedback(feedback);
    }
  }

  void _moveToNextStep() {
    _stepStartTime = null;
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _currentStatus = _steps[_currentStepIndex]['instruction'];
      });
      _speakInstruction("Perfect. " + _steps[_currentStepIndex]['instruction']);
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
    _ttsTimer = Timer(const Duration(seconds: 5), () {});
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
                      ...landmarkWidgets,
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

          // --- GUIDE IMAGE OVERLAY ---
          Positioned(
            top: 160, right: 20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white54, width: 2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                image: DecorationImage(image: AssetImage(widget.pose.imageUrl), fit: BoxFit.cover),
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
                  // Header row: step label + timer + close
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
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 22), 
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
