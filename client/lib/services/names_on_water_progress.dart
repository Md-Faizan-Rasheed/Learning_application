import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/name_chapters.dart';
import '../utils/names_of_allah.dart';
import '../utils/word_bank_entry.dart';

/// Local, per-device tracking of where a player is in cycling through all
/// 99 Names of Allah for the "Names of Allah" matching game — same
/// SharedPreferences-backed pattern as WordSearchStats/WordMasteryStore.
/// Sequential (not shuffled) order: simplest to reason about, and progress
/// only advances when a round is actually completed, not merely started —
/// abandoning a round mid-way leaves the pointer where it was, matching
/// Word Search's own "only advances on finish" convention.
class NamesOnWaterProgress {
  NamesOnWaterProgress._();

  static final NamesOnWaterProgress instance = NamesOnWaterProgress._();

  static const _key = 'names_on_water_progress';
  static const _minBatch = 5;
  static const _maxBatch = 7;
  static const _completedChaptersKey = 'names_on_water_completed_chapters';

  Future<int> _readNextIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return 0;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final index = data['nextIndex'] as int? ?? 0;
      return index % kNamesOfAllah.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _writeNextIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'nextIndex': index % kNamesOfAllah.length}));
  }

  /// The next round's batch (5-7 names, randomized per round), wrapping
  /// around to the start of the list once the end is reached.
  Future<List<WordEntry>> nextBatch({Random? random}) async {
    final rng = random ?? Random();
    final batchSize = _minBatch + rng.nextInt(_maxBatch - _minBatch + 1);
    final start = await _readNextIndex();

    final total = kNamesOfAllah.length;
    final size = min(batchSize, total);
    return [for (var i = 0; i < size; i++) kNamesOfAllah[(start + i) % total]];
  }

  /// Advances the pointer past a just-completed batch of [batchSize] names.
  /// Call only once a round is fully matched, not on abandon/restart.
  Future<void> advance(int batchSize) async {
    final start = await _readNextIndex();
    await _writeNextIndex(start + batchSize);
  }

  /// The fixed set of names for a chosen chapter — entirely independent of
  /// [nextBatch]/[advance]'s sequential pointer, so practicing a chapter
  /// never disturbs where "Continue My Journey" picks back up.
  List<WordEntry> batchForChapter(int chapterIndex) =>
      kNameChapters[chapterIndex].names;

  Future<Set<int>> completedChapters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_completedChaptersKey);
    if (raw == null) return {};
    return raw.map(int.parse).toSet();
  }

  /// Records a chapter as fully matched at least once. Purely additive
  /// (drives the ✓ badge on the chapter picker) — never touches the
  /// sequential pointer.
  Future<void> markChapterComplete(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await completedChapters();
    current.add(chapterIndex);
    await prefs.setStringList(
        _completedChaptersKey, current.map((i) => i.toString()).toList());
  }
}
