import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/local_progress_preferences.dart';
import '../models/daily_maze_progress.dart';

/// C2 — local persistence for [DailyMazeProgress], same
/// SharedPreferences + jsonEncode/jsonDecode pattern as every other save
/// in this feature.
class DailyMazeRepository {
  const DailyMazeRepository();

  static const _key = 'seerah_maze_daily_progress';

  Future<DailyMazeProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await LocalProgressPreferences.keyFor(_key);
    final raw = prefs.getString(key);
    if (raw == null) return const DailyMazeProgress();
    try {
      return DailyMazeProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DailyMazeProgress();
    }
  }

  Future<void> save(DailyMazeProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await LocalProgressPreferences.keyFor(_key);
    await prefs.setString(key, jsonEncode(progress.toJson()));
  }
}
