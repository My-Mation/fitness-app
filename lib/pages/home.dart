import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pushup_counter/services/support_widget.dart';
import 'package:pushup_counter/pages/pushup_counter.dart';
import 'package:pushup_counter/pages/app_selector.dart';
import 'package:pushup_counter/services/storage_service.dart';
import 'package:pushup_counter/services/usage_poller.dart';
import 'package:pushup_counter/services/usage_service.dart';
import 'package:pushup_counter/services/overlay_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  late final UsagePoller _poller;
  final _usageService = UsageService();
  final _storage = StorageService();
  final _overlay = OverlayService();
  Timer? _usageUpdateTimer;
  Map<String, Duration> _currentUsage = {};
  Map<String, Duration> _systemUsageStats = {};
  String? _limitExceededApp;

  @override
  void initState() {
    super.initState();
    _loadConfiguredApps();
    _startUsageUpdateTimer();
  }

  @override
  void dispose() {
    _usageUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfiguredApps() async {
    // Get all apps that have time limits configured
    _targets = await _getAppsWithLimits();
    _poller = UsagePoller(
      usageService: _usageService,
      storageService: _storage,
      overlayService: _overlay,
      targetPackages: _targets,
    )..start();
  }

  Future<List<String>> _getAppsWithLimits() async {
    // Get all package names that have limits set
    final allLimits = _storage.getAllLimits();
    return allLimits.keys.toList();
  }

  void _startUsageUpdateTimer() {
    _usageUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateUsageDisplay();
    });
  }

  void _updateUsageDisplay() async {
    if (!mounted) return;

    // Get system usage stats for today
    final systemStats = await _usageService.getDailyUsageStats();

    setState(() {
      _systemUsageStats = systemStats;

      // Update current usage for all tracked apps (prefer system stats if available)
      for (final pkg in _targets) {
        // Use system stats if available, otherwise fall back to our tracked usage
        final systemUsage = _systemUsageStats[pkg] ?? Duration.zero;
        final trackedUsage = _storage.getTodayUsage(pkg);

        // Use the maximum of system stats and our tracked usage for more accurate data
        _currentUsage[pkg] = systemUsage > trackedUsage ? systemUsage : trackedUsage;
      }

      // Check for limit exceeded
      for (final pkg in _targets) {
        final used = _currentUsage[pkg] ?? Duration.zero;
        final limit = _storage.getDailyLimit(pkg);
        if (limit > Duration.zero && used >= limit && _limitExceededApp != pkg) {
          _limitExceededApp = pkg;
          _showLimitExceededNotification(pkg);
          break; // Only show one notification at a time
        }
      }
    });
  }

  void _showLimitExceededNotification(String packageName) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Time limit exceeded for $packageName! Do pushups to unlock more time.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Do Pushups',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PushupCounter()),
            );
          },
        ),
      ),
    );
  }

  void _showUsageStats() async {
    // Check usage permission first
    final hasPermission = await _usageService.hasPermission();
    if (!hasPermission) {
      // Show permission request dialog
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Usage Access Required'),
            content: const Text(
              'To show detailed usage statistics like Digital Wellbeing, the app needs access to your usage data.\n\n'
              'You will be redirected to Android Settings to grant this permission.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Grant Permission'),
              ),
            ],
          );
        },
      );

      if (shouldRequest == true) {
        await _usageService.requestPermission();
        // Wait a moment for permission to be granted
        await Future.delayed(const Duration(seconds: 1));
      } else {
        return;
      }
    }

    // Show loading indicator while fetching fresh data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading usage data...'),
            ],
          ),
        );
      },
    );

    // Fetch fresh usage data
    final freshStats = await _usageService.getDailyUsageStats();
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog

      // Sort apps by usage time (descending)
      final sortedApps = freshStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('📊 Digital Wellbeing - Today\'s Usage'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: sortedApps.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No usage data available\n\nMake sure Usage Access permission is granted in Android Settings > Security > Usage Access',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: sortedApps.length,
                      itemBuilder: (context, index) {
                        final entry = sortedApps[index];
                        final packageName = entry.key;
                        final usage = entry.value;
                        final limit = _storage.getDailyLimit(packageName);
                        final hasLimit = limit > Duration.zero;

                        return ListTile(
                          title: Text(_getAppName(packageName)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Usage: ${_formatDuration(usage)}'),
                              if (hasLimit)
                                Text(
                                  'Limit: ${_formatDuration(limit)}',
                                  style: TextStyle(
                                    color: usage >= limit ? Colors.red : Colors.green,
                                    fontWeight: usage >= limit ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          trailing: hasLimit
                              ? Icon(
                                  usage >= limit ? Icons.warning : Icons.check_circle,
                                  color: usage >= limit ? Colors.red : Colors.green,
                                )
                              : null,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  String _getAppName(String packageName) {
    // Try to get app name from installed apps list
    try {
      // This is a simplified version - in a real app you'd cache this
      return packageName.split('.').last; // Just show last part of package name
    } catch (e) {
      return packageName;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h ${remainingMinutes} min';
      }
    }
  }

  List<String> _targets = [];

  static const List<Widget> _widgetOptions = <Widget>[
    Text('Home Page'),
    Text('Profile Page'),
    Text('Settings Page'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _widgetOptions.elementAt(_selectedIndex),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppSelector()),
                    );
                    // Reload configured apps after returning from selector
                    await _loadConfiguredApps();
                    setState(() {});
                  },
                  icon: const Icon(Icons.apps),
                  label: const Text('Disable Apps'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showUsageStats(),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Usage Stats'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PushupCounter()),
                );
              },
              child: const Text('Do Pushup'),
            ),
            const SizedBox(height: 20),
            const Text('Disabled Apps (with time limits):'),
            if (_targets.isEmpty)
              const Text('No apps disabled. Tap "Disable All Apps" to set time limits.')
            else
              for (final pkg in _targets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Card(
                    color: (_currentUsage[pkg] ?? Duration.zero) >= _storage.getDailyLimit(pkg) && _storage.getDailyLimit(pkg) > Duration.zero
                        ? Colors.red.shade100
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            pkg,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Limit: ${_formatDuration(_storage.getDailyLimit(pkg))} | Used: ${_formatDuration(_currentUsage[pkg] ?? Duration.zero)}',
                                style: TextStyle(
                                  color: (_currentUsage[pkg] ?? Duration.zero) >= _storage.getDailyLimit(pkg) && _storage.getDailyLimit(pkg) > Duration.zero
                                      ? Colors.red
                                      : Colors.black,
                                  fontWeight: (_currentUsage[pkg] ?? Duration.zero) >= _storage.getDailyLimit(pkg) && _storage.getDailyLimit(pkg) > Duration.zero
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (_systemUsageStats.containsKey(pkg))
                                Text(
                                  '📊 System Data: ${_formatDuration(_systemUsageStats[pkg]!)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          if ((_currentUsage[pkg] ?? Duration.zero) >= _storage.getDailyLimit(pkg) && _storage.getDailyLimit(pkg) > Duration.zero)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '🚫 TIME LIMIT EXCEEDED!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}