
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const String _streakKey = 'streak';

  Future<Map<String, dynamic>> getStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    final streakDataString = prefs.getString(_streakKey);
    if (streakDataString != null) {
      return json.decode(streakDataString);
    }
    return {'streak': 0, 'last_exercise_date': null};
  }

  Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final streakData = await getStreakData();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastExerciseDateString = streakData['last_exercise_date'];
    if (lastExerciseDateString != null) {
      final lastExerciseDate = DateTime.parse(lastExerciseDateString);
      final difference = today.difference(lastExerciseDate).inDays;

      if (difference == 1) {
        streakData['streak']++;
      } else if (difference > 1) {
        streakData['streak'] = 1;
      }
    } else {
      streakData['streak'] = 1;
    }

    streakData['last_exercise_date'] = today.toIso8601String();
    await prefs.setString(_streakKey, json.encode(streakData));
  }
}
