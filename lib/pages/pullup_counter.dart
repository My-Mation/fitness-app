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

class PullupCounter extends StatefulWidget {
  const PullupCounter({super.key});

  @override
  State<PullupCounter> createState() => _PullupCounterState();
}

class _PullupCounterState extends State<PullupCounter> {
  CameraController? _controller;
  final PoseService _poseService = PoseService();
  List<Pose> _poses = [];
  int _pullupCount = 0;
  bool _isUp = false;
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
      _countPullups(poses.first);
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

  void _countPullups(Pose pose) {
    // Required landmarks for pull-up detection
    final requiredLandmarks = [
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
    ];

    // Check if all required landmarks are visible
    for (final type in requiredLandmarks) {
      if (pose.landmarks[type] == null || pose.landmarks[type]!.likelihood < 0.5) {
        _statusText = 'Show full body';
        return;
      }
    }

    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist]!;
    final rWrist = pose.landmarks[PoseLandmarkType.rightWrist]!;
    final lHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rHip = pose.landmarks[PoseLandmarkType.rightHip]!;

    // Y-coordinates for key body parts
    final collarboneY = (lShoulder.y + rShoulder.y) / 2.0;
    final hipY = (lHip.y + rHip.y) / 2.0;
    final handsY = (lWrist.y + rWrist.y) / 2.0;

    // We can consider the body's center as the average of hip and collarbone
    final bodyY = (collarboneY + hipY) / 2.0;

    // Vertical distance between hands and body center
    final double distance = (bodyY - handsY).abs();

    // Hysteresis thresholds for pull-up detection (these values may need tuning)
    // These are ratios of the shoulder-hip distance to make it scale invariant.
    final shoulderHipDist = (hipY - collarboneY).abs();
    final double upThreshold = shoulderHipDist * 0.6; // Body is close to hands
    final double downThreshold = shoulderHipDist * 0.9; // Body is away from hands

    // State transition logic
    if (!_isUp && distance < upThreshold) {
      // Transition to 'up' state and count a pull-up
      _isUp = true;
      _pullupCount++;
      _statusText = 'Up';
      _lastRepAt = DateTime.now();
      if (_debugLogs) {
        debugPrint('Pull-up UP! Count: $_pullupCount');
      }
    } else if (_isUp && distance > downThreshold) {
      // Transition back to 'down' state
      _isUp = false;
      _statusText = 'Down';
      if (_debugLogs) {
        debugPrint('Pull-up DOWN. Ready for next rep.');
      }
    }
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
        appBar: AppBar(title: const Text('Pullup Counter')),
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
        title: const Text('Pullup Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () => Navigator.of(context).pop(_pullupCount),
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
              child: Text('Pullups: $_pullupCount', style: const TextStyle(color: Colors.white, fontSize: 24)),
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
