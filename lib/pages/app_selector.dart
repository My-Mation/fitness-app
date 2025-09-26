import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:pushup_counter/services/storage_service.dart';

class AppSelector extends StatefulWidget {
  const AppSelector({super.key});

  @override
  State<AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<AppSelector> {
  final StorageService _storage = StorageService();
  List<AppInfo> _installedApps = [];
  Map<String, Duration> _appLimits = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      // Filter out only our own app, keep system apps like YouTube, Chrome, etc.
      apps = apps.where((app) =>
        app.packageName != 'com.example.pushup_counter'
      ).toList();

      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });

      await _loadAppLimits();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
    }
  }

  Future<void> _loadAppLimits() async {
    final limits = _storage.getAllLimits();
    print('Loaded limits: $limits'); // Debug
    setState(() {
      _appLimits = limits;
    });
  }

  Future<void> _saveLimits() async {
    print('Saving limits: $_appLimits'); // Debug
    // Save all current limits
    for (final entry in _appLimits.entries) {
      if (entry.value > Duration.zero) {
        await _storage.setDailyLimit(entry.key, entry.value);
        print('Saved limit for ${entry.key}: ${entry.value}'); // Debug
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time limits saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _setTimeLimit(String packageName, Duration limit) async {
    // Save immediately to storage
    await _storage.setDailyLimit(packageName, limit);
    setState(() {
      _appLimits[packageName] = limit;
    });
    print('Set limit for $packageName: $limit'); // Debug
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} ${remainingMinutes} min';
      }
    }
  }

  Future<void> _showTimePicker(String packageName) async {
    final currentLimit = _appLimits[packageName] ?? Duration.zero;

    // Preset time options in minutes
    final timeOptions = [
      1, 2, 5, 10, 15, 30, // minutes
      60, 90, 120, 180, 240, 300, 360, 480, 600, 720, 1440 // hours (60=1h, 1440=24h)
    ];

    final selectedMinutes = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Daily Time Limit'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: timeOptions.length,
              itemBuilder: (context, index) {
                final minutes = timeOptions[index];
                final duration = Duration(minutes: minutes);
                final isSelected = currentLimit.inMinutes == minutes;

                String displayText;
                if (minutes < 60) {
                  displayText = '$minutes minutes';
                } else {
                  final hours = minutes ~/ 60;
                  final remainingMinutes = minutes % 60;
                  if (remainingMinutes == 0) {
                    displayText = '$hours hour${hours > 1 ? 's' : ''}';
                  } else {
                    displayText = '$hours hour${hours > 1 ? 's' : ''} ${remainingMinutes} min';
                  }
                }

                return ListTile(
                  title: Text(displayText),
                  leading: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () => Navigator.of(context).pop(minutes),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedMinutes != null) {
      final newLimit = Duration(minutes: selectedMinutes);
      await _setTimeLimit(packageName, newLimit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disable Apps - Set Time Limits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadAppLimits();
              setState(() {});
            },
            tooltip: 'Refresh limits from storage',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _installedApps.length,
              itemBuilder: (context, index) {
                final app = _installedApps[index];
                final currentLimit = _appLimits[app.packageName] ?? Duration.zero;
                final hasLimit = currentLimit > Duration.zero;

                return ListTile(
                  leading: app.icon != null
                      ? Image.memory(app.icon!, width: 40, height: 40)
                      : const Icon(Icons.android, size: 40),
                  title: Text(app.name ?? 'Unknown App'),
                  subtitle: Text(hasLimit
                      ? 'Limit: ${_formatDuration(currentLimit)}'
                      : 'No limit set'),
                  trailing: IconButton(
                    icon: Icon(hasLimit ? Icons.edit : Icons.add),
                    onPressed: () => _showTimePicker(app.packageName),
                  ),
                  onTap: () => _showTimePicker(app.packageName),
                );
              },
            ),
    );
  }
}