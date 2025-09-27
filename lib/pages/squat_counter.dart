import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/services/pose_service.dart';
import 'package:pushup_counter/widgets/full_body_skeleton_painter.dart';
import 'package:pushup_counter/widgets/diagnostics_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SquatCounter extends StatefulWidget {
  const SquatCounter({super.key});

  @override
  State<SquatCounter> createState() => _SquatCounterState();
}

class _SquatCounterState extends State<SquatCounter> {
  CameraController? _controller;
  final PoseService _poseService = PoseService();
  List<Pose> _poses = [];
  int _squatCount = 0;
  bool _isDown = false;
  DateTime _lastProcessed = DateTime.now();
  bool _debugLogs = false;
  late final bool _isFrontCamera;
  Size? _imageSize; // From CameraImage frames
  // Diagnostics
  int _frameCounter = 0;
  DateTime _lastFpsStamp = DateTime.now();
  double _fps = 0;
  bool _isCapturingDebug = false;
  String _statusText = '';
  DateTime? _lastRepAt;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    WakelockPlus.enable();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      // No cameras available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras found on this device.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high, // Increased resolution for better detection
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    _isFrontCamera = frontCamera.lensDirection == CameraLensDirection.front;
    setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    // Throttle to ~5 FPS
    if (DateTime.now().difference(_lastProcessed).inMilliseconds < 200) return;
    _lastProcessed = DateTime.now();

    // Effective image size after ML Kit rotation applied
    final isQuarterTurn = _controller!.description.sensorOrientation == 90 || _controller!.description.sensorOrientation == 270;
    _imageSize ??= isQuarterTurn
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());

    List<Pose> poses = const [];
    try {
      poses = await _poseService.detectFromCameraImage(image, _controller!.description);
    } catch (e) {
      if (_debugLogs) debugPrint('Pose detection error: $e');
    }
    if (poses.isNotEmpty) {
      _countSquats(poses.first);
    }

    setState(() {
      _poses = poses;
    });

    // FPS calculation
    _frameCounter++;
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastFpsStamp).inMilliseconds;
    if (elapsedMs >= 1000) {
      _fps = _frameCounter * 1000 / elapsedMs;
      _frameCounter = 0;
      _lastFpsStamp = now;
      if (_debugLogs) debugPrint('FPS: ${_fps.toStringAsFixed(1)} | Poses: ${_poses.length}');
    }
  }

  void _countSquats(Pose pose) {
    // Required landmarks for squat detection
    final requiredLandmarks = [
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    ];

    // Check if all required landmarks are visible
    for (final type in requiredLandmarks) {
      if (pose.landmarks[type] == null || pose.landmarks[type]!.likelihood < 0.5) {
        _statusText = 'Show full body';
        return;
      }
    }

    final lHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rHip = pose.landmarks[PoseLandmarkType.rightHip]!;
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee]!;
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee]!;
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle]!;
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle]!;

    // Calculate the angle of the knees
    final leftKneeAngle = _angleAt(lHip, lKnee, lAnkle);
    final rightKneeAngle = _angleAt(rHip, rKnee, rAnkle);
    final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2.0;

    // Hysteresis thresholds for squat detection
    const double downThreshold = 100.0; // Angle for a squat
    const double upThreshold = 160.0;   // Angle for standing up

    // State transition logic
    if (!_isDown && avgKneeAngle < downThreshold) {
      // Transition to 'down' state and count a squat
      _isDown = true;
      _squatCount++;
      _statusText = 'Down';
      _lastRepAt = DateTime.now();
      if (_debugLogs) {
        debugPrint('Squat DOWN! Count: $_squatCount, Angle: ${avgKneeAngle.toStringAsFixed(1)}');
      }
    } else if (_isDown && avgKneeAngle > upThreshold) {
      // Transition back to 'up' state
      _isDown = false;
      _statusText = 'Up';
      if (_debugLogs) {
        debugPrint('Squat UP. Ready for next rep. Angle: ${avgKneeAngle.toStringAsFixed(1)}');
      }
    }
  }

  double _angleAt(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ax = a.x - b.x; final ay = a.y - b.y;
    final cx = c.x - b.x; final cy = c.y - b.y;
    final double dot = ax * cx + ay * cy;
    final double magA = math.sqrt(ax * ax + ay * ay);
    final double magC = math.sqrt(cx * cx + cy * cy);
    if (magA == 0 || magC == 0) return 180;
    double cosTheta = dot / (magA * magC);
    if (cosTheta > 1) cosTheta = 1; if (cosTheta < -1) cosTheta = -1;
    return (math.acos(cosTheta) * 180 / math.pi);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Squat Counter')),
        body: const Center(
          child: Text(
            'Web version: Camera and pose detection features are not supported on web.\nPlease use the mobile app for full functionality.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Squat Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () => Navigator.of(context).pop(_squatCount),
            tooltip: 'Finish Exercise',
          ),
          IconButton(
            onPressed: () => setState(() => _debugLogs = !_debugLogs),
            icon: Icon(_debugLogs ? Icons.bug_report : Icons.bug_report_outlined),
            tooltip: 'Toggle debug logs',
          ),
          if (_debugLogs)
            IconButton(
              onPressed: _isCapturingDebug ? null : _debugCaptureAndDetect,
              icon: const Icon(Icons.camera),
              tooltip: 'Debug still detect',
            ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          LayoutBuilder(
            builder: (context, constraints) {
              final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
              final sourceSize = _imageSize ?? _controller!.value.previewSize!;
              return CustomPaint(
                size: overlaySize,
                painter: FullBodySkeletonPainter(
                  _poses,
                  sourceSize,
                  isFrontCamera: _isFrontCamera,
                ),
              );
            },
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text('Squats: $_squatCount', style: const TextStyle(color: Colors.white, fontSize: 24)),
            ),
          ),
          DiagnosticsOverlay(
            poseCount: _poses.length,
            fps: _fps,
            showNoPoseBanner: _poses.isEmpty,
            statusText: _statusText,
            showRepFlash: _lastRepAt != null && DateTime.now().difference(_lastRepAt!).inMilliseconds < 600,
          ),
        ],
      ),
    );
  }

  Future<void> _debugCaptureAndDetect() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturingDebug = true);
    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      if (_debugLogs) debugPrint('Captured debug photo: ${file.path}');

      final poses = await _poseService.detectFromFilePath(file.path);
      if (_debugLogs) debugPrint('Still detect poses: ${poses.length}');
      setState(() {
        _poses = poses;
      });
    } catch (e) {
      if (_debugLogs) debugPrint('Debug capture error: $e');
    } finally {
      try {
        await _controller!.startImageStream(_processCameraImage);
      } catch (_) {}
      if (mounted) setState(() => _isCapturingDebug = false);
    }
  }
}