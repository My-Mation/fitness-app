import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp({super.key});

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  static const platform = MethodChannel('com.example.pushup_counter/overlay');

  @override
  void initState() {
    super.initState();
    // Set up method channel to communicate with Android activity
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'closeOverlay':
        // Close the overlay
        await FlutterOverlayWindow.closeOverlay();
        break;
      default:
        throw MissingPluginException('notImplemented');
    }
  }

  Future<void> _startPushups() async {
    try {
      // Send signal to main app to start pushup counter
      await platform.invokeMethod('startPushups');
      // Close overlay after starting pushups
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      print('Error starting pushups: $e');
    }
  }

  Future<void> _exitApp() async {
    try {
      // Send signal to main app to close overlay
      await platform.invokeMethod('closeOverlay');
      // Close overlay
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      print('Error closing overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent
        body: Stack(
          children: [
            // Full-screen touch blocker
            GestureDetector(
              onTap: () {}, // Absorb all taps
              onPanUpdate: (_) {}, // Absorb all pan gestures
              onScaleUpdate: (_) {}, // Absorb all scale gestures
              child: Container(
                color: Colors.black.withOpacity(0.9), // Semi-transparent black background
              ),
            ),
            // Centered content
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade400, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_off,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "⏰ TIME'S UP!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Do pushups to unlock more time",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _startPushups,
                          icon: const Icon(Icons.fitness_center),
                          label: const Text('Do Pushups'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _exitApp,
                          icon: const Icon(Icons.close),
                          label: const Text('Exit App'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


