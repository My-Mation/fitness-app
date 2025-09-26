import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseService {
  PoseService()
      : _detector = PoseDetector(options: PoseDetectorOptions());

  final PoseDetector _detector;

  Future<List<Pose>> detectFromCameraImage(CameraImage image, CameraDescription description) async {
    final rotation = _rotationFromDegrees(description.sensorOrientation);
    final bytes = _yuv420ToNv21(image);
    final input = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
    return _detector.processImage(input);
  }

  Future<List<Pose>> detectFromFilePath(String path) async {
    final input = InputImage.fromFilePath(path);
    return _detector.processImage(input);
  }

  Future<void> dispose() async {
    await _detector.close();
  }

  InputImageRotation _rotationFromDegrees(int d) {
    switch (d) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    int dstIndex = 0;
    for (int row = 0; row < height; row++) {
      final int srcRowStart = row * yPlane.bytesPerRow;
      nv21.setRange(dstIndex, dstIndex + width, yPlane.bytes.sublist(srcRowStart, srcRowStart + width));
      dstIndex += width;
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    final int uPixelStride = uPlane.bytesPerPixel ?? 2;
    final int vPixelStride = vPlane.bytesPerPixel ?? 2;
    int uvIndex = ySize;
    for (int row = 0; row < uvHeight; row++) {
      final int uRowStart = row * uPlane.bytesPerRow;
      final int vRowStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        nv21[uvIndex++] = vPlane.bytes[vIndex];
        nv21[uvIndex++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }
}


