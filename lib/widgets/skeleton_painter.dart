import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  SkeletonPainter(this.poses, this.imageSize, {required this.isFrontCamera});

  // Only arms and shoulders (shortened forearm to keep within hand area)
  static const connections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
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
      // Collarbone (shoulder-to-shoulder) reference line only
      final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (lShoulder != null && rShoulder != null) {
        final s1 = Offset(lShoulder.x * scale + dx, lShoulder.y * scale + dy);
        final s2 = Offset(rShoulder.x * scale + dx, rShoulder.y * scale + dy);
        canvas.drawLine(s1, s2, linePaint);
      }

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

      // Draw shortened forearm segments to reduce overshoot beyond palm region
      final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
      final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      if (lElbow != null && lWrist != null) {
        final mx = (lElbow.x + lWrist.x) / 2;
        final my = (lElbow.y + lWrist.y) / 2;
        final ex = lElbow.x * scale + dx;
        final ey = lElbow.y * scale + dy;
        final mxs = mx * scale + dx;
        final mys = my * scale + dy;
        canvas.drawLine(Offset(ex, ey), Offset(mxs, mys), linePaint);
      }
      final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
      final rWrist = pose.landmarks[PoseLandmarkType.rightWrist];
      if (rElbow != null && rWrist != null) {
        final mx = (rElbow.x + rWrist.x) / 2;
        final my = (rElbow.y + rWrist.y) / 2;
        final ex = rElbow.x * scale + dx;
        final ey = rElbow.y * scale + dy;
        final mxs = mx * scale + dx;
        final mys = my * scale + dy;
        canvas.drawLine(Offset(ex, ey), Offset(mxs, mys), linePaint);
      }

      // Draw only shoulder, elbow, wrist points (both sides) with slightly larger elbow points
      final keys = [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
      ];
      for (final key in keys) {
        final landmark = pose.landmarks[key];
        if (landmark == null) continue;
        final x = landmark.x * scale + dx;
        final y = landmark.y * scale + dy;
        final radius = (key == PoseLandmarkType.leftElbow || key == PoseLandmarkType.rightElbow) ? 6.5 : 5.5;
        canvas.drawCircle(Offset(x, y), radius, pointPaint);
      }
    }

    if (isFrontCamera) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
