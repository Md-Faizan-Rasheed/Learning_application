import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/maze_progress.dart';

/// Local, per-device persistence for [MazeProgress] — same
/// SharedPreferences + jsonEncode/jsonDecode pattern as this app's other
/// local-progress services (e.g. services/names_on_water_progress.dart).
/// A thin wrapper so the storage mechanism can change later without
/// touching anything that calls this; corrupted/missing data is handled
/// entirely inside [MazeProgress.fromJson], which already falls back to
/// fresh defaults rather than throwing.
class MazeProgressRepository {
  const MazeProgressRepository();

  static const _key = 'seerah_maze_progress';

  Future<MazeProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const MazeProgress();
    try {
      return MazeProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MazeProgress();
    }
  }

  Future<void> save(MazeProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(progress.toJson()));
  }
}
