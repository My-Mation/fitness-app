import 'package:flutter/material.dart';

import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:pushup_counter/pages/app_editor.dart';
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
      List<AppInfo> apps = await InstalledApps.getInstalledApps(false, true);

      // Whitelist of keywords for apps we want to show.
      const List<String> allowedKeywords = [
        'youtube',
        'tiktok',
        'musically',
        'game', // A general keyword for games. A better solution would be to check the app category.
      ];

      final filteredApps = apps.where((app) {
        final packageName = app.packageName.toLowerCase();
        final appName = app.name.toLowerCase();

        // Exclude our own app
        if (packageName == 'com.example.pushup_counter') {
          return false;
        }

        for (final keyword in allowedKeywords) {
          if (packageName.contains(keyword) || appName.contains(keyword)) {
            return true;
          }
        }

        return false;
      }).toList();


      setState(() {
        _installedApps = filteredApps;
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
    setState(() {
      _appLimits = limits;
    });
  }

  Future<void> _setTimeLimit(String packageName, Duration limit) async {
    // Save immediately to storage
    await _storage.setDailyLimit(packageName, limit);
    setState(() {
      _appLimits[packageName] = limit;
    });
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

  void _navigateToAppEditor(String packageName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppEditor(packageName: packageName),
      ),
    );
    // Reload limits after returning from the editor
    await _loadAppLimits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disable Apps - Set Time Limits'),
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
                  trailing: Icon(hasLimit ? Icons.edit : Icons.add),
                  onTap: () {
                    if (hasLimit) {
                      _navigateToAppEditor(app.packageName);
                    } else {
                      _showTimePicker(app.packageName);
                    }
                  },
                );
              },
            ),
    );
  }
}
