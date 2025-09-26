import 'dart:async';
import 'package:pushup_counter/services/usage_service.dart';
import 'package:pushup_counter/services/storage_service.dart';
import 'package:pushup_counter/services/overlay_service.dart';

class UsagePoller {
  final UsageService usageService;
  final StorageService storageService;
  final OverlayService overlayService;
  final List<String> targetPackages;
  final Duration interval;

  Timer? _timer;
  String? _lastPackage;
  DateTime? _lastTick;

  UsagePoller({
    required this.usageService,
    required this.storageService,
    required this.overlayService,
    required this.targetPackages,
    this.interval = const Duration(seconds: 2), // More frequent checking
  });

  void start() {
    _lastTick = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final now = DateTime.now();
    final delta = now.difference(_lastTick ?? now);
    _lastTick = now;

    final pkg = await usageService.getForegroundAppPackage();
    if (pkg == null) return;

    // Skip our own app and system apps
    if (pkg == 'com.example.pushup_counter' ||
        pkg.startsWith('com.android.') ||
        pkg.startsWith('android.') ||
        pkg.startsWith('com.google.android.')) {
      _lastPackage = pkg;
      return;
    }

    // If app changed, reset timer for new app
    if (_lastPackage != pkg) {
      _lastPackage = pkg;
      // Could add logic here to reset session timer if needed
    }

    // Always accumulate usage for any app (not just selected ones)
    await storageService.addUsage(pkg, delta);
    final used = storageService.getTodayUsage(pkg);
    final limit = storageService.getDailyLimit(pkg);

    // Check if this app has a time limit set and if it's exceeded
    if (limit > Duration.zero && used >= limit) {
      print('Time limit exceeded for $pkg: used=$used, limit=$limit'); // Debug
      print('Attempting to show overlay...'); // Debug
      // show overlay
      final permissionGranted = await overlayService.ensurePermission();
      print('Overlay permission granted: $permissionGranted'); // Debug
      if (permissionGranted) {
        await overlayService.showOverlay();
        print('Overlay showOverlay() called'); // Debug
      } else {
        print('Overlay permission not granted, cannot show overlay'); // Debug
      }
    }

    // Additional check: if app has been used extensively today, show warnings
    final hoursUsed = used.inHours;
    if (hoursUsed >= 2 && limit > Duration.zero) {
      // Could add additional enforcement here
      print('Heavy usage detected for $pkg: ${hoursUsed}h used today');
    }
  }
}


