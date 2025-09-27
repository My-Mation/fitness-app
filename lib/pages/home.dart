import 'package:flutter/material.dart';
import 'package:pushup_counter/pages/pullup_counter.dart';
import 'package:pushup_counter/pages/pushup_counter.dart';
import 'package:pushup_counter/pages/squat_counter.dart';
import 'package:pushup_counter/pages/dumbbell_curl_counter.dart';
import 'package:pushup_counter/services/streak_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StreakService _streakService = StreakService();
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final streakData = await _streakService.getStreakData();
    setState(() {
      _streak = streakData['streak'];
    });
  }

  Future<void> _navigateToExercise(Widget exercisePage) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => exercisePage),
    );
    await _streakService.updateStreak();
    await _loadStreak();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Current Streak: $_streak',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _navigateToExercise(const PushupCounter()),
              child: const Text('Push-up Counter'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToExercise(const PullupCounter()),
              child: const Text('Pull-up Counter'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToExercise(const SquatCounter()),
              child: const Text('Squat Counter'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToExercise(const DumbbellCurlCounter()),
              child: const Text('Dumbbell Curl Counter'),
            ),
          ],
        ),
      ),
    );
  }
}
