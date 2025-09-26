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
            _navigateToPushupCounter();
          },
        ),
      ),
    );
  }

  void _navigateToPushupCounter() async {
    final pushupCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const PushupCounter()),
    );

    if (pushupCount != null && pushupCount > 0) {
      // For which app should we add time? For now, let's assume the one that last exceeded the limit.
      final appToCredit = _limitExceededApp;
      if (appToCredit != null) {
        final timeToAdd = Duration(minutes: pushupCount); // 1 pushup = 1 minute
        final currentLimit = _storage.getDailyLimit(appToCredit);
        final newLimit = currentLimit + timeToAdd;
        await _storage.setDailyLimit(appToCredit, newLimit);
        _updateUsageDisplay();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added $pushupCount minutes to $appToCredit!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pushup Productivity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppSelector()),
              );
              // Reload configured apps after returning from selector
              await _loadConfiguredApps();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showUsageStats(),
          ),
        ],
      ),
      body: _buildBody(),
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
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const Center(child: Text('Profile Page')); // Placeholder for profile
      case 2:
        return const Center(child: Text('Settings Page')); // Placeholder for settings
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomePage() {
    return Column(
      children: [
        Expanded(
          child: _targets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No apps are currently being restricted. Tap the apps icon in the top right to select apps to restrict.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _targets.length,
                  itemBuilder: (context, index) {
                    final pkg = _targets[index];
                    final limit = _storage.getDailyLimit(pkg);
                    final usage = _currentUsage[pkg] ?? Duration.zero;
                    final isExceeded = limit > Duration.zero && usage >= limit;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isExceeded ? Colors.red.shade900 : null,
                      child: ListTile(
                        title: Text(
                          _getAppName(pkg),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isExceeded ? Colors.white : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Limit: ${_formatDuration(limit)} | Used: ${_formatDuration(usage)}',
                              style: TextStyle(color: isExceeded ? Colors.white70 : null),
                            ),
                            if (_systemUsageStats.containsKey(pkg))
                              Text(
                                '📊 System Data: ${_formatDuration(_systemUsageStats[pkg]!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isExceeded ? Colors.lightBlue.shade100 : Colors.blue,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: isExceeded
                            ? const Icon(Icons.warning, color: Colors.white)
                            : const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _navigateToPushupCounter,
            icon: const Icon(Icons.fitness_center),
            label: const Text('Do a Pushup'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), // Full width
            ),
          ),
        ),
      ],
    );
  }
}
