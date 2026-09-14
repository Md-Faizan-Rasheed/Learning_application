import 'dart:math';

import 'word_search_generator.dart';

/// The Word Search Daily Challenge: one shared puzzle per calendar date, the
/// same for every player, so friends can compare scores. There's no server
/// round-trip to fetch it — the date alone deterministically picks the
/// category and seeds the grid, so every device generates the identical
/// puzzle locally. Difficulty is fixed (not player-chosen) so a comparison
/// is actually apples-to-apples.
const kDailyChallengeDifficulty = WordSearchDifficulty.medium;

/// Calendar date to key everything off — device-local, not UTC. Like most
/// daily-challenge games, players in different timezones see "today" change
/// at a slightly different real-world moment; matching the device's own
/// clock is more intuitive than a global day boundary nobody can see.
DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// ISO date string (e.g. "2026-09-14") — the value reported to the backend
/// so a completed attempt lands on the right day's leaderboard row.
String dailyChallengeDateString([DateTime? date]) {
  final d = date ?? _today();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Rotates through the categories by day so the daily challenge doesn't
/// always land on the same topic.
WordSearchCategory dailyChallengeCategory([DateTime? date]) {
  final dayNumber = (date ?? _today()).difference(DateTime(2026, 1, 1)).inDays;
  const categories = WordSearchCategory.values;
  final index = dayNumber % categories.length;
  return categories[index < 0 ? index + categories.length : index];
}

/// A seed derived purely from the calendar date, so every device's `Random`
/// produces the exact same puzzle for the same day.
int dailyChallengeSeed([DateTime? date]) {
  final iso = dailyChallengeDateString(date);
  return iso.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
}

/// Generates today's (or a given date's) shared Daily Challenge puzzle.
/// Deliberately ignores WordMasteryStore's per-player weighting — everyone
/// needs the same word set for the comparison to be fair.
WordSearchPuzzle generateDailyChallengePuzzle([DateTime? date]) {
  return generatePuzzleForDifficulty(
    kDailyChallengeDifficulty,
    category: dailyChallengeCategory(date),
    random: Random(dailyChallengeSeed(date)),
  );
}
