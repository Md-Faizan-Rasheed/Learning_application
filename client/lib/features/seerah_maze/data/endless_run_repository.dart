import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/local_progress_preferences.dart';
import '../models/endless_best_run.dart';

/// C3 — local persistence for [EndlessBestRun], same SharedPreferences +
/// jsonEncode/jsonDecode pattern as every other save in this feature.
class EndlessRunRepository {
  const EndlessRunRepository();

  static const _key = 'seerah_maze_endless_best';

  Future<EndlessBestRun> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await LocalProgressPreferences.keyFor(_key);
    final raw = prefs.getString(key);
    if (raw == null) return const EndlessBestRun();
    try {
      return EndlessBestRun.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const EndlessBestRun();
    }
  }

  Future<void> save(EndlessBestRun run) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await LocalProgressPreferences.keyFor(_key);
    await prefs.setString(key, jsonEncode(run.toJson()));
  }
}
