import '../../models/daily_maze_progress.dart';
import 'daily_seed.dart';

/// What actually happened when a daily completion was recorded, for the
/// UI to react to (a "streak continued" toast reads differently from a
/// "that streak was reset" one) without re-deriving it from two progress
/// snapshots itself.
enum DailyStreakOutcome {
  /// The very first daily completion ever recorded.
  started,

  /// Already completed today — this call changed nothing; any further
  /// play today is "practice", per the spec's own framing.
  alreadyCountedToday,

  /// Completed yesterday, so today extends the streak by one.
  continued,

  /// There was a gap of 2+ days since the last counted day, so the
  /// streak restarts at 1 rather than continuing from whatever it was.
  broken,

  /// The stored last-counted date is *after* today's real UTC date —
  /// the clock was wound back, or had been wound forward earlier and
  /// just got corrected. Per the spec's "handle clock tampering
  /// conservatively": today's play still counts as a fresh start (the
  /// player isn't punished for a clock they may not control), but the
  /// suspect prior streak is discarded rather than trusted or extended.
  clockTamperDetected,
}

class DailyStreakResult {
  const DailyStreakResult({required this.progress, required this.outcome});

  final DailyMazeProgress progress;
  final DailyStreakOutcome outcome;
}

/// C2's streak rules, as one pure function: given the progress as it was
/// stored and the real "today" (always UTC, always date-only), what
/// should the new progress be after a daily completion right now?
///
/// Deliberately takes [nowUtc] as a parameter rather than reading the
/// system clock itself, so every rule above is directly testable against
/// a fixed, fake "now" instead of depending on whatever day the test
/// happens to run on.
DailyStreakResult recordDailyCompletion({
  required DailyMazeProgress progress,
  required DateTime nowUtc,
}) {
  final today = utcDateOnly(nowUtc);
  final last = progress.lastCountedUtcDate;

  if (last != null && last.isAtSameMomentAs(today)) {
    return DailyStreakResult(
      progress: progress.withHistoryTrimmed(nowUtc).copyWith(
        playedUtcDates: {...progress.playedUtcDates, today},
      ),
      outcome: DailyStreakOutcome.alreadyCountedToday,
    );
  }

  final DailyStreakOutcome outcome;
  final int newStreak;

  if (last == null) {
    outcome = DailyStreakOutcome.started;
    newStreak = 1;
  } else if (last.isAfter(today)) {
    // The stored date is in the future relative to real "now" — never
    // trust it enough to extend (or even read) whatever streak number
    // came with it.
    outcome = DailyStreakOutcome.clockTamperDetected;
    newStreak = 1;
  } else if (today.difference(last).inDays == 1) {
    outcome = DailyStreakOutcome.continued;
    newStreak = progress.currentStreak + 1;
  } else {
    outcome = DailyStreakOutcome.broken;
    newStreak = 1;
  }

  final updated = progress.withHistoryTrimmed(nowUtc).copyWith(
    currentStreak: newStreak,
    bestStreak: newStreak > progress.bestStreak ? newStreak : progress.bestStreak,
    lastCountedUtcDate: today,
    playedUtcDates: {...progress.playedUtcDates, today},
  );

  return DailyStreakResult(progress: updated, outcome: outcome);
}
