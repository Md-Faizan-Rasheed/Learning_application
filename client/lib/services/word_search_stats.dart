import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/word_search_generator.dart';

/// Local-only best-time/completion tracking for the Word Search game — it
/// has no server component (see PracticeScreen for the same "fully
/// client-side" philosophy), so this is the only record of progress there
/// is. One JSON blob in shared_preferences, same pattern AuthService already
/// uses for the login session. Stats are kept per category *and*
/// difficulty, since a best time in "Prophets/Hard" says nothing about
/// "Hijri Months/Easy".
class WordSearchStats {
  WordSearchStats._();

  static final WordSearchStats instance = WordSearchStats._();

  static const _key = 'word_search_stats';

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Best completion time in seconds for [category]/[difficulty], or null
  /// if that combination has never been completed.
  Future<int?> bestSeconds(
    WordSearchCategory category,
    WordSearchDifficulty difficulty,
  ) async {
    final data = await _read();
    final categoryData = data[category.name] as Map<String, dynamic>?;
    final entry = categoryData?[difficulty.name] as Map<String, dynamic>?;
    return entry?['bestSeconds'] as int?;
  }

  /// Records a completed puzzle, updating the best time for
  /// [category]/[difficulty] if [seconds] beats it (or if there's no prior
  /// best).
  Future<void> recordCompletion(
    WordSearchCategory category,
    WordSearchDifficulty difficulty, {
    required int seconds,
  }) async {
    final data = await _read();
    final categoryData =
        Map<String, dynamic>.from(data[category.name] as Map<String, dynamic>? ?? {});
    final entry = Map<String, dynamic>.from(
        categoryData[difficulty.name] as Map<String, dynamic>? ?? {});
    final currentBest = entry['bestSeconds'] as int?;
    if (currentBest == null || seconds < currentBest) {
      entry['bestSeconds'] = seconds;
    }
    entry['completed'] = (entry['completed'] as int? ?? 0) + 1;
    categoryData[difficulty.name] = entry;
    data[category.name] = categoryData;
    await _write(data);
  }
}
