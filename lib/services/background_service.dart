import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pushup_counter/services/usage_service.dart';
import 'package:pushup_counter/services/storage_service.dart';
import 'package:pushup_counter/services/overlay_service.dart';
import 'package:pushup_counter/services/usage_poller.dart';

class BackgroundServiceController {
  final UsageService usageService;
  final StorageService storageService;
  final OverlayService overlayService;
  final List<String> targetPackages;

  BackgroundServiceController({required this.usageService, required this.storageService, required this.overlayService, required this.targetPackages});

  Future<void> initialize() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: false,
        autoStart: false,
        autoStartOnBoot: false,
      ),
      iosConfiguration: IosConfiguration(autoStart: true),
    );
  }

  static void _onStart(ServiceInstance service) async {
    // Initialize Hive in background
    await Hive.initFlutter();
    final storage = StorageService();
    await storage.init();
    final usage = UsageService();
    final overlay = OverlayService();

    // Get target packages
    final targets = storage.getAllLimits().keys.toList();

    // Start poller
    final poller = UsagePoller(
      usageService: usage,
      storageService: storage,
      overlayService: overlay,
      targetPackages: targets,
      interval: const Duration(seconds: 1),
    );
    poller.start();

    // Set up foreground service notification
    service.invoke('setAsForeground', {
      'notificationId': 1,
      'notificationTitle': 'Pushup Counter',
      'notificationContent': 'Monitoring app usage in background',
    });

    // Keep service alive
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Update targets in case limits changed
      final newTargets = storage.getAllLimits().keys.toList();
      poller.targetPackages.clear();
      poller.targetPackages.addAll(newTargets);
    });
  }
}


