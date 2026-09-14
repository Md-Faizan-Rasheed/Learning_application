import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/word_bank_entry.dart';
import '../utils/word_search_generator.dart';

/// Light, local-only spaced-repetition signal for Word Search: remembers,
/// per category, which words a player has ever needed a hint for versus
/// found unaided. Puzzle generation then weights word selection so
/// never-seen and previously-hinted words come up more often than words
/// already mastered — instead of a pure uniform shuffle that's just as
/// likely to keep re-serving words the player already knows cold.
///
/// Deliberately client-side and separate from the backend's
/// word_search_finds table: that table exists to answer "has this account
/// ever found word X" for achievements, and is keyed by authenticated user.
/// This store exists to answer "should the *next local* puzzle lean toward
/// word X", works for guests too, and never needs to leave the device.
class WordMasteryStore {
  WordMasteryStore._();

  static final WordMasteryStore instance = WordMasteryStore._();

  static const _key = 'word_search_mastery';

  // Higher weight = more likely to be picked for the next puzzle.
  static const _weightUnseen = 4;
  static const _weightHinted = 3;
  static const _weightMastered = 1;

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

  /// Records one finished puzzle: every word in [allWords] was found (a
  /// puzzle only completes once everything is found), and [hintedWords] is
  /// whichever of those needed a hint along the way. "Ever hinted" is
  /// sticky — one hinted session is enough to keep a word in rotation,
  /// mirroring how the rest of this feature treats struggle as a lasting
  /// signal rather than something that decays back out on its own.
  Future<void> recordSession({
    required WordSearchCategory category,
    required Set<String> allWords,
    required Set<String> hintedWords,
  }) async {
    final data = await _read();
    final categoryData =
        Map<String, dynamic>.from(data[category.name] as Map<String, dynamic>? ?? {});
    for (final word in allWords) {
      final wasHinted = hintedWords.contains(word);
      final alreadyHinted = categoryData[word] == true;
      categoryData[word] = wasHinted || alreadyHinted;
    }
    data[category.name] = categoryData;
    await _write(data);
  }

  /// A selection weight per word in [bank] — unseen words and words ever
  /// hinted-on outweigh mastered ones. Always covers every word in [bank],
  /// even ones with no recorded history yet.
  Future<Map<String, int>> priorityFor(
    WordSearchCategory category,
    List<WordEntry> bank,
  ) async {
    final data = await _read();
    final categoryData = data[category.name] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in bank)
        entry.word: !categoryData.containsKey(entry.word)
            ? _weightUnseen
            : (categoryData[entry.word] == true ? _weightHinted : _weightMastered),
    };
  }
}
