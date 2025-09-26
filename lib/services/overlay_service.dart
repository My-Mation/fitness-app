import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  Future<bool> ensurePermission() async {
    print('Checking overlay permission...');
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    print('Overlay permission granted: $granted');
    if (granted) return true;
    print('Requesting overlay permission...');
    final result = await FlutterOverlayWindow.requestPermission();
    print('Overlay permission request result: $result');
    return result ?? false;
  }

  Future<void> showOverlay() async {
    print('showOverlay() called - attempting to display overlay');
    try {
      await FlutterOverlayWindow.showOverlay(
        height: -1,
        width: -1,
        alignment: OverlayAlignment.center,
        overlayTitle: "Pushup Counter Overlay",
        overlayContent: "Time limit exceeded - do pushups to unlock!",
        flag: OverlayFlag.focusPointer, // Make overlay receive focus and block touches
        enableDrag: false,
        positionGravity: PositionGravity.none,
        startPosition: const OverlayPosition(0, 0),
      );
      print('FlutterOverlayWindow.showOverlay() completed successfully');
    } catch (e) {
      print('Error showing overlay: $e');
    }
  }

  Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}


