import 'package:usage_stats/usage_stats.dart';

class UsageService {
  Future<bool> hasPermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  Future<bool> requestPermission() async {
    await UsageStats.grantUsagePermission();
    return await hasPermission();
  }

  Future<String?> getForegroundAppPackage() async {
    try {
      final events = await UsageStats.queryEvents(DateTime.now().subtract(const Duration(minutes: 1)), DateTime.now());
      events.sort((a, b) {
        final aTime = DateTime.tryParse(a.timeStamp ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b.timeStamp ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      for (final e in events.reversed) {
        if (e.eventType == 'MOVE_TO_FOREGROUND') {
          return e.packageName;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Duration>> getDailyUsageStats() async {
    try {
      print('Checking usage permission...');
      final permissionGranted = await hasPermission();
      print('Usage permission granted: $permissionGranted');

      if (!permissionGranted) {
        print('No usage permission, requesting...');
        await requestPermission();
        final newPermissionStatus = await hasPermission();
        print('New permission status: $newPermissionStatus');
        if (!newPermissionStatus) {
          return {};
        }
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('Querying usage stats from $startOfDay to $endOfDay');

      final stats = await UsageStats.queryUsageStats(startOfDay, endOfDay);
      print('Received ${stats.length} usage stats');

      final Map<String, Duration> usageMap = {};

      for (final stat in stats) {
        print('Stat: ${stat.packageName} - ${stat.totalTimeInForeground}');
        if (stat.packageName != null && stat.totalTimeInForeground != null) {
          final totalTimeMs = int.tryParse(stat.totalTimeInForeground!) ?? 0;
          if (totalTimeMs > 0) {
            usageMap[stat.packageName!] = Duration(milliseconds: totalTimeMs);
            print('Added ${stat.packageName}: ${Duration(milliseconds: totalTimeMs)}');
          }
        }
      }

      print('Returning ${usageMap.length} usage entries');
      return usageMap;
    } catch (e) {
      print('Error getting daily usage stats: $e');
      return {};
    }
  }

  Future<Duration> getAppUsageForToday(String packageName) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final stats = await UsageStats.queryUsageStats(startOfDay, now);
      for (final stat in stats) {
        if (stat.packageName == packageName && stat.totalTimeInForeground != null) {
          final totalTimeMs = int.tryParse(stat.totalTimeInForeground!) ?? 0;
          return Duration(milliseconds: totalTimeMs);
        }
      }
      return Duration.zero;
    } catch (e) {
      print('Error getting app usage for today: $e');
      return Duration.zero;
    }
  }
}


