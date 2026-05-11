import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:typed_data';
import '../utils/pose_painter.dart';
import '../models/yoga_pose.dart';

class CameraScreen extends StatefulWidget {
  final YogaPose pose;
  const CameraScreen({super.key, required this.pose});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  List<Pose> _poses = [];
  int _poseCount = 0;
  String _currentStatus = "Initializing...";
  late String _targetPoseName;
  double _accuracy = 0.0;
  
  late PoseDetector _poseDetector;
  final FlutterTts _tts = FlutterTts();
  Timer? _ttsTimer;
  InputImageRotation? _currentRotation;
  List<dynamic> _allPoseRules = [];
  Map<String, dynamic>? _currentPoseRules;

  @override
  void initState() {
    super.initState();
    _targetPoseName = widget.pose.name;
    _initializePoseDetector();
    _loadPoseRules();
    _initializeCamera();
    _initializeTTS();
  }

  Future<void> _loadPoseRules() async {
    try {
      final String response = await rootBundle.loadString('assets/data/pose_rules.json');
      final data = await json.decode(response);
      setState(() {
        _allPoseRules = data;
        _currentPoseRules = _allPoseRules.firstWhere(
          (element) => element['poseName'] == _targetPoseName,
          orElse: () => null,
        );
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    String welcomeMsg = "Beginning $_targetPoseName. Please observe the reference image.";
    await _tts.speak(welcomeMsg);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final frontCamera = cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888);
    try {
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.startImageStream(_processCameraImage);
      setState(() { _currentStatus = "Ready! Align your body."; });
    } catch (e) { debugPrint("Camera error: $e"); }
  }

  @override
  void dispose() { _ttsTimer?.cancel(); _controller?.dispose(); _poseDetector.close(); super.dispose(); }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _controller!.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = sensorOrientation;
      if (_controller!.description.lensDirection == CameraLensDirection.front) rotationCompensation = (sensorOrientation + 0) % 360;
      else rotationCompensation = (sensorOrientation - 0 + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else if (Platform.isIOS) rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;
    _currentRotation = rotation;
    if (Platform.isAndroid) {
      final yPlane = image.planes[0]; final uPlane = image.planes[1]; final vPlane = image.planes[2];
      final yBytes = yPlane.bytes; final uBytes = uPlane.bytes; final vBytes = vPlane.bytes;
      try {
        final int width = image.width; final int height = image.height;
        final int yStride = yPlane.bytesPerRow; final int uvStride = vPlane.bytesPerRow;
        final int vLen = vBytes.length; final int uLen = uBytes.length;
        final Uint8List nv21 = Uint8List(width * height + (width * height ~/ 2));
        for (int row = 0; row < height; row++) {
          final int sourceOffset = row * yStride; final int targetOffset = row * width;
          final int copyLength = (sourceOffset + width <= yBytes.length) ? width : (yBytes.length - sourceOffset);
          if (copyLength > 0) nv21.setRange(targetOffset, targetOffset + copyLength, yBytes.sublist(sourceOffset, sourceOffset + copyLength));
        }
        int offset = width * height; int uvHeight = height ~/ 2;
        for (int row = 0; row < uvHeight; row++) {
          int rowStart = row * uvStride;
          for (int col = 0; col < width; col += 2) {
            if (uvStride == yStride && vLen > (width * height ~/ 4)) {
              if (rowStart + col < vLen) nv21[offset++] = vBytes[rowStart + col];
              if (rowStart + col + 1 < vLen) nv21[offset++] = vBytes[rowStart + col + 1];
            } else {
              final int pIdx = rowStart + (col ~/ 2);
              if (pIdx < vLen) nv21[offset++] = vBytes[pIdx];
              if (pIdx < uLen) nv21[offset++] = uBytes[pIdx];
            }
          }
        }
        return InputImage.fromBytes(bytes: nv21, metadata: InputImageMetadata(size: Size(width.toDouble(), height.toDouble()), rotation: rotation, format: InputImageFormat.nv21, bytesPerRow: width));
      } catch (e) { return null; }
    } else {
      return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: InputImageFormat.bgra8888, bytesPerRow: image.planes[0].bytesPerRow));
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) { _isProcessing = false; return; }
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted) {
        setState(() { _poses = poses; _poseCount = poses.length; });
        if (poses.isNotEmpty) _updatePoseStatus(poses.first);
      }
    } catch (e) { debugPrint("Error: $e"); } finally { _isProcessing = false; }
  }

  double _getAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    double angle = (math.atan2(p3.y - p2.y, p3.x - p2.x) - math.atan2(p1.y - p2.y, p1.x - p2.x)).abs();
    angle = angle * 180 / math.pi;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  void _updatePoseStatus(Pose pose) {
    if (_currentPoseRules == null) return;

    final landmarks = pose.landmarks;
    bool allRulesPassed = true;
    String feedback = "Perfect position! Keep holding.";

    final List<dynamic> rules = _currentPoseRules!['rules'];
    
    for (var rule in rules) {
      String joint = rule['joint'];
      double? angle;

      // Dynamic joint mapping
      if (joint.contains("arm")) {
        final shoulder = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
        final elbow = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
        final wrist = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
        if (shoulder != null && elbow != null && wrist != null) angle = _getAngle(shoulder, elbow, wrist);
      } else if (joint.contains("knee") || joint.contains("leg")) {
        final hip = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
        final knee = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee];
        final ankle = joint.startsWith("left") ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];
        if (hip != null && knee != null && ankle != null) angle = _getAngle(hip, knee, ankle);
      } else if (joint == "spine") {
        final shoulder = landmarks[PoseLandmarkType.leftShoulder];
        final hip = landmarks[PoseLandmarkType.leftHip];
        final knee = landmarks[PoseLandmarkType.leftKnee];
        if (shoulder != null && hip != null && knee != null) angle = _getAngle(shoulder, hip, knee);
      }

      if (angle != null) {
        if (angle < rule['idealMin']) {
          allRulesPassed = false;
          feedback = rule['messageLow'];
          break;
        } else if (angle > rule['idealMax']) {
          allRulesPassed = false;
          feedback = rule['messageHigh'] ?? "Adjust your position";
          break;
        }
      } else {
        allRulesPassed = false;
        feedback = "Stand back for full body view";
        break;
      }
    }

    setState(() {
      _accuracy = allRulesPassed ? 0.95 : 0.4;
      _currentStatus = feedback;
    });

    _provideVoiceFeedback(feedback);
  }

  void _provideVoiceFeedback(String message) {
    if (_ttsTimer?.isActive ?? false) return;
    _tts.speak(message);
    _ttsTimer = Timer(const Duration(seconds: 6), () {});
  }

  String _getGuideImage() {
    if (_targetPoseName.contains("Tree")) return "assets/images/tree_pose.png";
    if (_targetPoseName.contains("Warrior")) return "assets/images/warrior_pose.png";
    if (_targetPoseName.contains("Plank")) return "assets/images/plank_pose.png";
    return "assets/images/mountain_pose.png";
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scale: scale, child: Center(child: CameraPreview(_controller!))),
          if (_poses.isNotEmpty && _currentRotation != null)
            CustomPaint(painter: PosePainter(_poses, _controller!.value.previewSize!, _currentRotation!, isFrontCamera: _controller!.description.lensDirection == CameraLensDirection.front)),
          Positioned(
            top: 60, right: 20,
            child: Container(
              width: 120, height: 160,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.greenAccent, width: 2), boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black45)]),
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(_getGuideImage(), fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 60, left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.fitness_center, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(_targetPoseName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    _currentStatus,
                    style: TextStyle(
                      color: _accuracy > 0.7 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 26, fontWeight: FontWeight.bold,
                      shadows: const [Shadow(blurRadius: 10, color: Colors.black, offset: Offset(2, 2))],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Row(
              children: [
                _buildStatTile("Landmarks", "${_poses.isNotEmpty ? _poses.first.landmarks.length : 0}", Icons.visibility),
                const SizedBox(width: 12),
                _buildStatTile("Accuracy", "${(_accuracy * 100).toInt()}%", Icons.check_circle),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(height: 60, width: 60, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 30)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
