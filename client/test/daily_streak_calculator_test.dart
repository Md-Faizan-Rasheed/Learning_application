import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/daily/daily_streak_calculator.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';

void main() {
  group('first-ever completion', () {
    test('starts the streak at 1', () {
      final result = recordDailyCompletion(
        progress: const DailyMazeProgress(),
        nowUtc: DateTime.utc(2026, 5, 1),
      );

      expect(result.outcome, DailyStreakOutcome.started);
      expect(result.progress.currentStreak, 1);
      expect(result.progress.bestStreak, 1);
      expect(result.progress.lastCountedUtcDate, DateTime.utc(2026, 5, 1));
    });
  });

  group('playing again the same day', () {
    test('does not change the streak — "further plays allowed as practice"', () {
      final afterFirst = recordDailyCompletion(
        progress: const DailyMazeProgress(),
        nowUtc: DateTime.utc(2026, 5, 1, 9),
      ).progress;

      final afterSecond = recordDailyCompletion(
        progress: afterFirst,
        nowUtc: DateTime.utc(2026, 5, 1, 18),
      );

      expect(afterSecond.outcome, DailyStreakOutcome.alreadyCountedToday);
      expect(afterSecond.progress.currentStreak, 1);
    });

    test('still records today in the calendar history even if already counted', () {
      final progress = DailyMazeProgress(
        currentStreak: 3,
        bestStreak: 3,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 1));

      expect(result.progress.playedUtcDates, contains(DateTime.utc(2026, 5, 1)));
    });
  });

  group('playing on consecutive days', () {
    test('extends the streak by one', () {
      final progress = DailyMazeProgress(
        currentStreak: 4,
        bestStreak: 4,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 2));

      expect(result.outcome, DailyStreakOutcome.continued);
      expect(result.progress.currentStreak, 5);
    });

    test('updates bestStreak once the current streak passes it', () {
      final progress = DailyMazeProgress(
        currentStreak: 4,
        bestStreak: 4,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 2));

      expect(result.progress.bestStreak, 5);
    });

    test('bestStreak never decreases even after the current streak later resets', () {
      final progress = DailyMazeProgress(
        currentStreak: 1,
        bestStreak: 10,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      // A 5-day gap: the streak breaks, but the historic best must survive.
      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 10));

      expect(result.progress.currentStreak, 1);
      expect(result.progress.bestStreak, 10);
    });
  });

  group('a gap of 2+ days', () {
    test('resets the streak to 1 rather than continuing it', () {
      final progress = DailyMazeProgress(
        currentStreak: 7,
        bestStreak: 7,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 4));

      expect(result.outcome, DailyStreakOutcome.broken);
      expect(result.progress.currentStreak, 1);
    });
  });

  group('clock tampering: stored last-played date is in the future', () {
    test('does not extend or trust the existing streak', () {
      final progress = DailyMazeProgress(
        currentStreak: 50,
        bestStreak: 50,
        lastCountedUtcDate: DateTime.utc(2026, 6, 1), // "the future" relative to nowUtc below
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 1));

      expect(result.outcome, DailyStreakOutcome.clockTamperDetected);
      expect(result.progress.currentStreak, 1,
          reason: 'the spec: do not award a streak off a future-dated record');
    });

    test('still lets today genuinely count going forward (not punished to zero)', () {
      final progress = DailyMazeProgress(
        currentStreak: 50,
        lastCountedUtcDate: DateTime.utc(2026, 6, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 1));

      expect(result.progress.currentStreak, 1);
      expect(result.progress.lastCountedUtcDate, DateTime.utc(2026, 5, 1));
    });

    test('bestStreak is not inflated by the untrusted figure either', () {
      final progress = DailyMazeProgress(
        currentStreak: 50,
        bestStreak: 50,
        lastCountedUtcDate: DateTime.utc(2026, 6, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 1));

      // bestStreak(50) is still >= the new streak(1), so it's correctly
      // left alone — the point is the CURRENT streak was not extended
      // off the suspicious record, not that history is erased.
      expect(result.progress.bestStreak, 50);
    });

    test('a same-day tampered date (not future, exactly today) is unaffected by this rule', () {
      // Guards against an off-by-one: "in the future" must mean strictly
      // after today, not today itself (that's the ordinary
      // alreadyCountedToday path).
      final progress = DailyMazeProgress(
        currentStreak: 3,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
      );

      final result = recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 1));

      expect(result.outcome, DailyStreakOutcome.alreadyCountedToday);
    });
  });

  test('ignores time-of-day — only the calendar date drives every rule', () {
    final progress = DailyMazeProgress(
      currentStreak: 2,
      lastCountedUtcDate: DateTime.utc(2026, 5, 1),
    );

    final result =
        recordDailyCompletion(progress: progress, nowUtc: DateTime.utc(2026, 5, 2, 23, 59));

    expect(result.outcome, DailyStreakOutcome.continued);
    expect(result.progress.currentStreak, 3);
  });
}
