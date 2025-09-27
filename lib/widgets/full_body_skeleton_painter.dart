import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class FullBodySkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  FullBodySkeletonPainter(this.poses, this.imageSize, {required this.isFrontCamera});

  // Full body skeleton connections, excluding the face
  static const connections = [
    // Torso
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    // Arms
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    // Legs
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()..color = Colors.white..strokeWidth = 7..style = PaintingStyle.fill;
    final linePaint = Paint()..color = Colors.white..strokeWidth = 5..style = PaintingStyle.stroke;

    if (isFrontCamera) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final double scale = math.max(size.width / imageSize.width, size.height / imageSize.height);
    final double dx = (size.width - imageSize.width * scale) / 2;
    final double dy = (size.height - imageSize.height * scale) / 2;

    for (final pose in poses) {
      // Draw connections
      for (final connection in connections) {
        final start = pose.landmarks[connection[0]];
        final end = pose.landmarks[connection[1]];
        if (start != null && end != null) {
          final startX = start.x * scale + dx;
          final startY = start.y * scale + dy;
          final endX = end.x * scale + dx;
          final endY = end.y * scale + dy;
          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);
        }
      }

      // Draw landmark points
      final keys = [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      ];

      for (final key in keys) {
        final landmark = pose.landmarks[key];
        if (landmark == null) continue;
        final x = landmark.x * scale + dx;
        final y = landmark.y * scale + dy;
        canvas.drawCircle(Offset(x, y), 5.5, pointPaint);
      }
    }

    if (isFrontCamera) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
