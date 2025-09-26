import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';

class UsageService {
  Future<bool> hasPermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (e) {
      // This can happen on some devices, where the settings screen is not opened.
    }
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
      if (!await hasPermission()) {
        return {};
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stats = await UsageStats.queryUsageStats(startOfDay, now);

      final Map<String, Duration> usageMap = {};
      for (final stat in stats) {
        if (stat.packageName != null && stat.totalTimeInForeground != null) {
          int totalTimeMs = 0;
          try {
            // Robust parsing to handle both integer and double strings.
            totalTimeMs = (double.tryParse(stat.totalTimeInForeground!) ?? 0).toInt();
          } catch (e) {
            // If any error occurs during parsing, default to 0 and continue.
            totalTimeMs = 0;
          }
          
          if (totalTimeMs > 0) {
            usageMap[stat.packageName!] = Duration(milliseconds: totalTimeMs);
          }
        }
      }
      return usageMap;
    } on PlatformException {
      // This may be due to manufacturer restrictions (e.g., on Oppo, Xiaomi phones).
      return {};
    } catch (e) {
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
          int totalTimeMs = 0;
          try {
            // Robust parsing to handle both integer and double strings.
            totalTimeMs = (double.tryParse(stat.totalTimeInForeground!) ?? 0).toInt();
          } catch (e) {
            // If any error occurs during parsing, default to 0.
            totalTimeMs = 0;
          }
          return Duration(milliseconds: totalTimeMs);
        }
      }
      return Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }
}
