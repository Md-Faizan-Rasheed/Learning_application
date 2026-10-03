import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/daily_maze_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DailyMazeProgress JSON', () {
    test('round-trips every field', () {
      final progress = DailyMazeProgress(
        currentStreak: 5,
        bestStreak: 9,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
        playedUtcDates: {DateTime.utc(2026, 4, 29), DateTime.utc(2026, 5, 1)},
      );

      final restored = DailyMazeProgress.fromJson(progress.toJson());

      expect(restored.currentStreak, 5);
      expect(restored.bestStreak, 9);
      expect(restored.lastCountedUtcDate, DateTime.utc(2026, 5, 1));
      expect(restored.playedUtcDates, {DateTime.utc(2026, 4, 29), DateTime.utc(2026, 5, 1)});
    });

    test('a fresh DailyMazeProgress defaults to no streak and no history', () {
      const progress = DailyMazeProgress();

      expect(progress.currentStreak, 0);
      expect(progress.bestStreak, 0);
      expect(progress.lastCountedUtcDate, isNull);
      expect(progress.playedUtcDates, isEmpty);
    });

    test('an empty map falls back to fresh defaults', () {
      final restored = DailyMazeProgress.fromJson({});

      expect(restored.currentStreak, 0);
      expect(restored.playedUtcDates, isEmpty);
    });

    test('a malformed date string in the history is dropped, not thrown', () {
      final restored = DailyMazeProgress.fromJson({
        'playedUtcDates': ['2026-05-01', 'not-a-date', '2026-13-99'],
      });

      expect(restored.playedUtcDates, {DateTime.utc(2026, 5, 1)});
    });

    test('a malformed lastCountedUtcDate falls back to null rather than throwing', () {
      final restored = DailyMazeProgress.fromJson({
        'currentStreak': 3,
        'lastCountedUtcDate': 'garbage',
      });

      expect(restored.lastCountedUtcDate, isNull);
      expect(restored.currentStreak, 3);
    });
  });

  group('withHistoryTrimmed', () {
    test('drops dates older than the retention window', () {
      final old = DateTime.utc(2020, 1, 1);
      final recent = DateTime.utc(2026, 5, 1);
      final progress = DailyMazeProgress(playedUtcDates: {old, recent});

      final trimmed = progress.withHistoryTrimmed(DateTime.utc(2026, 5, 2));

      expect(trimmed.playedUtcDates, {recent});
    });

    test('returns the same instance (no-op) when nothing needs trimming', () {
      final progress = DailyMazeProgress(playedUtcDates: {DateTime.utc(2026, 5, 1)});

      final result = progress.withHistoryTrimmed(DateTime.utc(2026, 5, 2));

      expect(result.playedUtcDates, progress.playedUtcDates);
    });
  });

  group('DailyMazeRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('a fresh install loads fresh defaults', () async {
      const repo = DailyMazeRepository();

      final progress = await repo.load();

      expect(progress.currentStreak, 0);
    });

    test('save then load round-trips', () async {
      const repo = DailyMazeRepository();
      final saved = DailyMazeProgress(
        currentStreak: 7,
        bestStreak: 7,
        lastCountedUtcDate: DateTime.utc(2026, 5, 1),
        playedUtcDates: {DateTime.utc(2026, 5, 1)},
      );

      await repo.save(saved);
      final loaded = await repo.load();

      expect(loaded.currentStreak, 7);
      expect(loaded.lastCountedUtcDate, DateTime.utc(2026, 5, 1));
      expect(loaded.playedUtcDates, {DateTime.utc(2026, 5, 1)});
    });

    test('corrupted stored data falls back to fresh defaults instead of throwing', () async {
      SharedPreferences.setMockInitialValues(
          {'seerah_maze_daily_progress': 'not valid json at all'});
      const repo = DailyMazeRepository();

      final progress = await repo.load();

      expect(progress.currentStreak, 0);
    });
  });
}
