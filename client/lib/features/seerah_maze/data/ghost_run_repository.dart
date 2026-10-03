import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ghost_sample.dart';

/// C1 — "Save per-level, local only": one best-run ghost per level,
/// stored under its own SharedPreferences key the same way
/// data/maze_progress_repository.dart stores MazeProgress — a separate
/// key per level rather than one combined blob, since a level's ghost is
/// only ever read or written in isolation (never "load every level's
/// ghost at once").
class GhostRunRepository {
  const GhostRunRepository();

  String _keyFor(int levelId) => 'seerah_maze_ghost_level_$levelId';

  /// The best recorded run for [levelId], oldest sample first — or an
  /// empty list if there's no best run yet, or the stored data is
  /// corrupt. Never throws: a bad save is equivalent to no save, not a
  /// reason to block the level from loading.
  Future<List<GhostSample>> loadBest(int levelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(levelId));
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      final samples = decoded.map(GhostSample.fromJson).toList();
      if (samples.any((s) => s == null)) return const [];
      return samples.cast<GhostSample>();
    } catch (_) {
      return const [];
    }
  }

  /// Overwrites [levelId]'s stored ghost unconditionally — the caller
  /// (MazeGameScreen) is the one that decides a run was actually an
  /// improvement before calling this, so this repository has no opinion
  /// about what "best" means.
  Future<void> save(int levelId, List<GhostSample> samples) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(levelId), jsonEncode(samples.map((s) => s.toJson()).toList()));
  }
}
