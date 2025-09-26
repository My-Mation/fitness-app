import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String limitsBox = 'limits';
  static const String usageBox = 'usage';
  static const String statsBox = 'stats';
  static const String selectedAppsBox = 'selected_apps';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(limitsBox);
    await Hive.openBox(usageBox);
    await Hive.openBox(statsBox);
    await Hive.openBox(selectedAppsBox);
  }

  Future<void> setDailyLimit(String package, Duration limit) async {
    final box = Hive.box(limitsBox);
    await box.put(package, limit.inSeconds);
  }

  Future<void> removeDailyLimit(String package) async {
    final box = Hive.box(limitsBox);
    await box.delete(package);
  }

  Duration getDailyLimit(String package) {
    final box = Hive.box(limitsBox);
    final seconds = box.get(package, defaultValue: 0) as int;
    return Duration(seconds: seconds);
  }

  Future<void> addUsage(String package, Duration delta) async {
    final box = Hive.box(usageBox);
    final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}:$package';
    final int current = box.get(todayKey, defaultValue: 0) as int;
    await box.put(todayKey, current + delta.inSeconds);
  }

  Duration getTodayUsage(String package) {
    final box = Hive.box(usageBox);
    final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}:$package';
    final int current = box.get(todayKey, defaultValue: 0) as int;
    return Duration(seconds: current);
  }

  Future<void> addPushups(int count) async {
    final box = Hive.box(statsBox);
    final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}:pushups';
    final int current = box.get(todayKey, defaultValue: 0) as int;
    await box.put(todayKey, current + count);
  }

  Future<void> setSelectedApps(List<String> packages) async {
    final box = Hive.box(selectedAppsBox);
    await box.put('selected_apps', packages);
  }

  List<String> getSelectedApps() {
    final box = Hive.box(selectedAppsBox);
    final packages = box.get('selected_apps', defaultValue: <String>[]) as List<dynamic>;
    return packages.cast<String>();
  }

  Map<String, Duration> getAllLimits() {
    final box = Hive.box(limitsBox);
    final Map<String, Duration> limits = {};
    for (final key in box.keys) {
      final seconds = box.get(key, defaultValue: 0) as int;
      if (seconds > 0) {
        limits[key] = Duration(seconds: seconds);
      }
    }
    return limits;
  }
}
