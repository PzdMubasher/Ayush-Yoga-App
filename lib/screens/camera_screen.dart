import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _targetPoseName = widget.pose.name;
    _initializePoseDetector();
    _initializeCamera();
    _initializeTTS();
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
    String welcomeMsg = "Beginning $_targetPoseName. Please observe the reference image on your screen.";
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
      setState(() { _currentStatus = "Ready! Align your body with the guide."; });
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
    double angle = math.atan2(p3.y - p2.y, p3.x - p2.x) - math.atan2(p1.y - p2.y, p1.x - p2.x);
    angle = (angle * 180 / math.pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  void _updatePoseStatus(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (lShoulder == null || lElbow == null || lWrist == null || rShoulder == null || rElbow == null || rWrist == null || lHip == null || lKnee == null || lAnkle == null) {
      setState(() { _currentStatus = "Stand back for full body view"; _accuracy = 0.0; });
      return;
    }

    double lArmAngle = _getAngle(lShoulder, lElbow, lWrist);
    double rArmAngle = _getAngle(rShoulder, rElbow, rWrist);
    double lLegAngle = _getAngle(lHip, lKnee, lAnkle);

    bool isCorrect = false;
    String status = "Matching...";

    if (_targetPoseName.contains("Tree")) {
      bool armsUp = lArmAngle > 150 && rArmAngle > 150 && lWrist.y < lShoulder.y;
      bool legBent = lLegAngle < 100 || _getAngle(pose.landmarks[PoseLandmarkType.rightHip]!, pose.landmarks[PoseLandmarkType.rightKnee]!, pose.landmarks[PoseLandmarkType.rightAnkle]!) < 100;
      isCorrect = armsUp && legBent;
      status = isCorrect ? "Perfect Vrikshasana!" : (armsUp ? "Place your foot on the inner thigh" : "Reach your arms to the sky");
    } else if (_targetPoseName.contains("Warrior")) {
      bool armsWide = (lArmAngle > 150 && rArmAngle > 150) && (lWrist.y > lShoulder.y - 50 && lWrist.y < lShoulder.y + 50);
      isCorrect = armsWide;
      status = isCorrect ? "Strong Virabhadrasana!" : "Extend your arms at shoulder height";
    } else if (_targetPoseName.contains("Plank")) {
      // Plank: Straight arms and straight body (legs angle near 180)
      bool armsStraight = lArmAngle > 160 && rArmAngle > 160;
      bool bodyStraight = lLegAngle > 160;
      isCorrect = armsStraight && bodyStraight;
      status = isCorrect ? "Strong Plank!" : "Keep your body in a straight line";
    } else {
      isCorrect = lArmAngle > 160 && rArmAngle > 160;
      status = isCorrect ? "Steady Tadasana!" : "Stand tall and lengthen your spine";
    }

    setState(() { _accuracy = isCorrect ? 0.95 : 0.4; _currentStatus = status; });
    if (isCorrect) _provideVoiceFeedback("Focus on your breath. Excellent hold.");
    else _provideVoiceFeedback(status);
  }

  void _provideVoiceFeedback(String message) {
    if (_ttsTimer?.isActive ?? false) return;
    _tts.speak(message);
    _ttsTimer = Timer(const Duration(seconds: 7), () {});
  }

  String _getGuideImage() {
    if (_targetPoseName.contains("Tree")) return "assets/images/tree_pose.png";
    if (_targetPoseName.contains("Warrior")) return "assets/images/warrior_pose.png";
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
          
          // Reference Guide Image
          Positioned(
            top: 60, right: 20,
            child: Container(
              width: 120, height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black45)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(_getGuideImage(), fit: BoxFit.contain),
              ),
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
                _buildStatTile("Poses", "$_poseCount", Icons.visibility),
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
