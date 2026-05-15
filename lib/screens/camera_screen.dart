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
import 'dart:typed_data';
import '../utils/pose_painter.dart';
import '../models/yoga_pose.dart';

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
  String _currentStatus = "Initializing AI Coach...";
  late String _targetPoseName;
  double _accuracy = 0.0;
  
  late PoseDetector _poseDetector;
  final FlutterTts _tts = FlutterTts();
  Timer? _ttsTimer;
  Timer? _sessionTimer;
  int _secondsRemaining = 0;
  int _prepCountdown = 3; // 3 second prep
  bool _isPrepping = true;
  InputImageRotation? _currentRotation;
  
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
    _loadPoseRules();
    _initializeCamera();
    _initializeTTS();
    _startPrepCountdown();
  }

  void _startPrepCountdown() {
    _speakInstruction("Get ready! Starting in 3, 2, 1");
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepCountdown > 1) {
        setState(() => _prepCountdown--);
      } else {
        timer.cancel();
        setState(() => _isPrepping = false);
        _startSessionTimer();
        _speakInstruction("Go!");
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _sessionTimer?.cancel();
        _moveToNextStep(); // Finish or next
      }
    });
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
        _speakInstruction(_steps[0]['instruction']);
      }
    } catch (e) { debugPrint("JSON Load Error: $e"); }
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base, mode: PoseDetectionMode.stream));
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _controller = CameraController(front, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888);
    try {
      await _controller!.initialize();
      if (!mounted) return;
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
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage != null) {
        final poses = await _poseDetector.processImage(inputImage);
        if (mounted && poses.isNotEmpty) {
          setState(() { _poses = poses; });
          _updateStepProgress(poses.first);
        }
      }
    } catch (e) { debugPrint("Process Error: $e"); } finally { _isProcessing = false; }
  }

  void _updateStepProgress(Pose pose) {
    if (_currentStepIndex >= _steps.length) return;

    final currentStep = _steps[_currentStepIndex];
    final rules = currentStep['rules'] as List<dynamic>;
    bool allRulesPassed = true;
    String feedback = currentStep['instruction'];

    for (var rule in rules) {
      double? angle = _calculateAngle(pose, rule['joint']);
      
      // Level adjustments: More lenient for beginners
      double tolerance = 0;
      if (widget.level == "Beginner") tolerance = 15;
      if (widget.level == "Intermediate") tolerance = 5;

      if (angle == null || angle < (rule['idealMin'] - tolerance) || angle > (rule['idealMax'] + tolerance)) {
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

      if (duration >= requiredHold) {
        _moveToNextStep();
      } else {
        setState(() { _accuracy = 1.0; _currentStatus = "Hold... ${requiredHold - duration}s"; });
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
    } else {
      setState(() { _currentStatus = "Session Complete! Namaste."; _accuracy = 1.0; });
      _speakInstruction("Workout complete. Well done. Namaste.");
    }
  }

  double? _calculateAngle(Pose pose, String joint) {
    final landmarks = pose.landmarks;
    if (joint.contains("arm")) {
      final s = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
      final e = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
      final w = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
      if (s != null && e != null && w != null) return _getAngle(s, e, w);
    } else if (joint.contains("knee") || joint.contains("leg")) {
      final h = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
      final k = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee];
      final a = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];
      if (h != null && k != null && a != null) return _getAngle(h, k, a);
    } else if (joint == "spine") {
      final s = landmarks[PoseLandmarkType.leftShoulder];
      final h = landmarks[PoseLandmarkType.leftHip];
      final k = landmarks[PoseLandmarkType.leftKnee];
      if (s != null && h != null && k != null) return _getAngle(s, h, k);
    }
    return null;
  }

  double _getAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    double angle = (math.atan2(p3.y - p2.y, p3.x - p2.x) - math.atan2(p1.y - p2.y, p1.x - p2.x)).abs();
    angle = angle * 180 / math.pi;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  void _speakInstruction(String msg) { _tts.speak(msg); }

  void _provideVoiceFeedback(String message) {
    if (_ttsTimer?.isActive ?? false) return;
    _tts.speak(message);
    _ttsTimer = Timer(const Duration(seconds: 5), () {});
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _controller!.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = (sensorOrientation + 0) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;
    _currentRotation = rotation;
    final width = image.width; final height = image.height;
    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    // Fast path for YUV conversion (simplified for brevity but stable)
    for (int i = 0; i < width * height; i++) nv21[i] = image.planes[0].bytes[i];
    return InputImage.fromBytes(bytes: nv21, metadata: InputImageMetadata(size: Size(width.toDouble(), height.toDouble()), rotation: rotation, format: InputImageFormat.nv21, bytesPerRow: width));
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (_poses.isNotEmpty && _currentRotation != null) CustomPaint(painter: PosePainter(_poses, _controller!.value.previewSize!, _currentRotation!, isFrontCamera: true)),
          
          // --- TOP STATUS BAR ---
          Positioned(
            top: 50, left: 20, right: 20,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _steps.isEmpty ? 0 : (_currentStepIndex + 1) / _steps.length, 
                  backgroundColor: Colors.white10, 
                  valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                  minHeight: 6,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    _currentStatus, 
                    textAlign: TextAlign.center, 
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),

          // --- LIVE GUIDE IMAGE OVERLAY ---
          Positioned(
            top: 150, right: 20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54, width: 2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                image: DecorationImage(image: AssetImage(widget.pose.imageUrl), fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Step ${_currentStepIndex + 1}/${_steps.length}", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
                    Text("Time: ${_formatTime(_secondsRemaining)}", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                CircleAvatar(backgroundColor: Colors.redAccent, radius: 25, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
              ],
            ),
          ),
          if (_isPrepping)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("GET READY", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text("$_prepCountdown", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 100, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
