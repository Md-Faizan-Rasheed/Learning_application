import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/achievements/explorer_level.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/models/endless_best_run.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_achievement.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';

/// D2 — the Explorer Level XP aggregation and level-threshold math, pure
/// functions over a hand-built MazeAchievementInputs.
void main() {
  const emptyInputs = MazeAchievementInputs(
    progress: MazeProgress(),
    daily: DailyMazeProgress(),
    endless: EndlessBestRun(),
    ghostLevelsRecorded: 0,
    totalLevels: 10,
  );

  test('fresh data earns zero XP and sits at level 1', () {
    expect(explorerXpFor(emptyInputs), 0);
    expect(explorerLevelForXp(0), 1);
  });

  test('stars, facts and no-hints clears each add their own XP', () {
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(
        starsByLevel: {1: 3, 2: 2},
        collectedFactLevelIds: {1},
        noHintsClearedLevelIds: {1},
      ),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    // 5 stars * 10 + 1 fact * 15 + 1 no-hints clear * 20 = 50 + 15 + 20 = 85.
    // firstSteps also unlocks (level 1 has a star entry) for +50.
    expect(explorerXpFor(inputs), 85 + 50);
  });

  test('streak and endless XP are each capped so one stat cannot dominate', () {
    const atCap = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(bestStreak: 60),
      endless: EndlessBestRun(bestRoundsCleared: 150),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    const overCap = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(bestStreak: 6000),
      endless: EndlessBestRun(bestRoundsCleared: 15000),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(explorerXpFor(overCap), explorerXpFor(atCap),
        reason: 'XP must stop increasing past the cap, not keep scaling unbounded');
  });

  test('unlocking achievements contributes XP of its own', () {
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {1: 1}), // unlocks firstSteps
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    // 1 star * 10 = 10, plus firstSteps unlocked = +50.
    expect(explorerXpFor(inputs), 60);
  });

  test('level thresholds are quadratic: level 1 at 0, level 2 at 50, level 3 at 200', () {
    expect(explorerLevelThreshold(1), 0);
    expect(explorerLevelThreshold(2), 50);
    expect(explorerLevelThreshold(3), 200);
  });

  test('explorerLevelForXp finds the right level at and just below each threshold', () {
    expect(explorerLevelForXp(49), 1);
    expect(explorerLevelForXp(50), 2);
    expect(explorerLevelForXp(199), 2);
    expect(explorerLevelForXp(200), 3);
  });

  test('level never decreases as xp increases', () {
    var previousLevel = 1;
    for (var xp = 0; xp <= 3000; xp += 17) {
      final level = explorerLevelForXp(xp);
      expect(level, greaterThanOrEqualTo(previousLevel));
      previousLevel = level;
    }
  });

  test('ExplorerLevelInfo reports sensible progress within the current level', () {
    final info = explorerLevelInfoForXp(125); // between level-2 (50) and level-3 (200)
    expect(info.level, 2);
    expect(info.levelStartXp, 50);
    expect(info.nextLevelXp, 200);
    expect(info.progressToNext, closeTo(0.5, 0.001));
  });

  test('ExplorerLevelInfo clamps progress to exactly 1.0 right at a threshold', () {
    final info = explorerLevelInfoForXp(50);
    expect(info.level, 2);
    expect(info.progressToNext, 0.0);
  });
}
