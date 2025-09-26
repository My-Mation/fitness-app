import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestBatteryOptimizationIgnore() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> checkBatteryOptimizationIgnored() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.systemAlertWindow,
      Permission.camera,
      Permission.ignoreBatteryOptimizations,
    ];

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }
}