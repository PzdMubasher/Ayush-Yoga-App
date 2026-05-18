import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  PosePainter(this.poses, this.absoluteImageSize, this.rotation, {this.isFrontCamera = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00FF88); // Bright neon green

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final jointBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF00FF88);

    for (final pose in poses) {
      // Draw joints
      pose.landmarks.forEach((_, landmark) {
        final offset = _translateLandmark(landmark, size);
        canvas.drawCircle(offset, 6, jointPaint);
        canvas.drawCircle(offset, 6, jointBorderPaint);
      });

      // Draw skeleton connections
      void drawBone(PoseLandmarkType t1, PoseLandmarkType t2) {
        final j1 = pose.landmarks[t1];
        final j2 = pose.landmarks[t2];
        if (j1 != null && j2 != null) {
          canvas.drawLine(
            _translateLandmark(j1, size),
            _translateLandmark(j2, size),
            linePaint,
          );
        }
      }

      // Body
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      // Arms
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      // Legs
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  Offset _translateLandmark(PoseLandmark landmark, Size canvasSize) {
    double x, y;

    switch (rotation) {
      case InputImageRotation.rotation90deg:
        x = landmark.x * canvasSize.width / absoluteImageSize.height;
        y = landmark.y * canvasSize.height / absoluteImageSize.width;
        break;
      case InputImageRotation.rotation270deg:
        x = canvasSize.width - landmark.x * canvasSize.width / absoluteImageSize.height;
        y = landmark.y * canvasSize.height / absoluteImageSize.width;
        break;
      default:
        x = landmark.x * canvasSize.width / absoluteImageSize.width;
        y = landmark.y * canvasSize.height / absoluteImageSize.height;
    }

    // Mirror for front camera
    if (isFrontCamera) {
      x = canvasSize.width - x;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}
