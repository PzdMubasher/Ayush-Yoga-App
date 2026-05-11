import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.imageSize, this.rotation, {this.isFrontCamera = false});

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.greenAccent;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.orangeAccent;

    for (final pose in poses) {
      void paintLine(
          PoseLandmarkType type1, PoseLandmarkType type2, Paint paint) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];

        if (landmark1 == null || landmark2 == null) return;

        canvas.drawLine(
            Offset(translateX(landmark1.x, rotation, size, imageSize),
                translateY(landmark1.y, rotation, size, imageSize)),
            Offset(translateX(landmark2.x, rotation, size, imageSize),
                translateY(landmark2.y, rotation, size, imageSize)),
            paint);
      }

      // Draw arms
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw Body
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, paint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, paint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, paint);

      // Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);

      // Draw points
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
            Offset(
              translateX(landmark.x, rotation, size, imageSize),
              translateY(landmark.y, rotation, size, imageSize),
            ),
            4,
            Paint()..color = Colors.white);
      });
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.poses != poses;
  }

  double translateX(
      double x, InputImageRotation rotation, Size size, Size imageSize) {
    double adjustedX = x;
    if (Platform.isAndroid && isFrontCamera) {
      // Flip X for front camera mirroring
      if (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg) {
        adjustedX = imageSize.height - x;
      } else {
        adjustedX = imageSize.width - x;
      }
    }

    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return adjustedX * size.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return size.width - adjustedX * size.width / imageSize.height;
      case InputImageRotation.rotation180deg:
        return size.width - adjustedX * size.width / imageSize.width;
      default:
        return adjustedX * size.width / imageSize.width;
    }
  }

  double translateY(
      double y, InputImageRotation rotation, Size size, Size imageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * size.height / imageSize.width;
      default:
        return y * size.height / imageSize.height;
    }
  }
}
