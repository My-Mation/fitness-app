import 'package:flutter/material.dart';

class DiagnosticsOverlay extends StatelessWidget {
  final int poseCount;
  final double fps;
  final bool showNoPoseBanner;
  final String statusText;
  final bool showRepFlash;

  const DiagnosticsOverlay({super.key, required this.poseCount, required this.fps, required this.showNoPoseBanner, required this.statusText, required this.showRepFlash});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(8),
            child: Text(
              'Poses: $poseCount | FPS: ${fps.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        if (showNoPoseBanner)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              alignment: Alignment.center,
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'No pose detected. Ensure good lighting and your upper body is in frame.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (statusText.isNotEmpty)
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                statusText,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (showRepFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.black54,
                  child: const Text(
                    'Rep +1',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
