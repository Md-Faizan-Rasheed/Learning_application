import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/models/endless_best_run.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_achievement.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';

/// D1 — every achievement's progress function, pure and independent of
/// any repository: feed it a hand-built MazeAchievementInputs and check
/// the ratio and unlock threshold.
void main() {
  MazeAchievementDef defFor(MazeAchievementId id) =>
      kMazeAchievements.firstWhere((a) => a.id == id);

  const emptyInputs = MazeAchievementInputs(
    progress: MazeProgress(),
    daily: DailyMazeProgress(),
    endless: EndlessBestRun(),
    ghostLevelsRecorded: 0,
    totalLevels: 10,
  );

  test('every achievement starts at zero progress with fresh data', () {
    for (final def in kMazeAchievements) {
      expect(def.progressOf(emptyInputs), 0.0, reason: '${def.id} should start at 0');
      expect(def.isUnlocked(emptyInputs), isFalse);
    }
  });

  test('firstSteps unlocks the moment level 1 has a star entry', () {
    final def = defFor(MazeAchievementId.firstSteps);
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {1: 1}),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.isUnlocked(inputs), isTrue);
  });

  test('halfwayThere reaches 1.0 at exactly half the levels finished', () {
    final def = defFor(MazeAchievementId.halfwayThere);
    final inputs = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {for (var i = 1; i <= 5; i++) i: 1}),
      daily: const DailyMazeProgress(),
      endless: const EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.progressOf(inputs), 1.0);
    expect(def.isUnlocked(inputs), isTrue);
  });

  test('journeysEnd needs every single level finished, not just most', () {
    final def = defFor(MazeAchievementId.journeysEnd);
    final almost = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {for (var i = 1; i <= 9; i++) i: 1}),
      daily: const DailyMazeProgress(),
      endless: const EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.isUnlocked(almost), isFalse);
    expect(def.progressOf(almost), closeTo(0.9, 0.001));

    final all = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {for (var i = 1; i <= 10; i++) i: 1}),
      daily: const DailyMazeProgress(),
      endless: const EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.isUnlocked(all), isTrue);
  });

  test('perfectCampaign requires 3 stars on literally every level, not just the total', () {
    final def = defFor(MazeAchievementId.perfectCampaign);
    // 30 total stars spread unevenly (some levels below 3) must not count,
    // even though the SUM happens to hit the same number another
    // distribution would need for a true perfect clear.
    final uneven = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {
        for (var i = 1; i <= 9; i++) i: 3,
        10: 3,
      }),
      daily: const DailyMazeProgress(),
      endless: const EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.isUnlocked(uneven), isTrue, reason: '10 levels at 3 stars each = 30, truly perfect');

    const lopsided = MazeAchievementInputs(
      progress: MazeProgress(starsByLevel: {1: 3, 2: 3, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3, 8: 3, 9: 3}),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(def.isUnlocked(lopsided), isFalse, reason: 'only 9 levels played, never reaches 30');
  });

  test('seerahScholar and noHintsMaster track their own sets independently', () {
    final scholar = defFor(MazeAchievementId.seerahScholar);
    final noHints = defFor(MazeAchievementId.noHintsMaster);
    final inputs = MazeAchievementInputs(
      progress: MazeProgress(
        collectedFactLevelIds: {for (var i = 1; i <= 10; i++) i},
        noHintsClearedLevelIds: {1, 2},
      ),
      daily: const DailyMazeProgress(),
      endless: const EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(scholar.isUnlocked(inputs), isTrue);
    expect(noHints.isUnlocked(inputs), isFalse);
    expect(noHints.progressOf(inputs), closeTo(0.2, 0.001));
  });

  test('racingSpirit needs ghost records on at least half the levels', () {
    final def = defFor(MazeAchievementId.racingSpirit);
    const partial = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 4,
      totalLevels: 10,
    );
    expect(def.isUnlocked(partial), isFalse);

    const enough = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 5,
      totalLevels: 10,
    );
    expect(def.isUnlocked(enough), isTrue);
  });

  test('the three streak achievements use the best streak, not the current one', () {
    final gettingStarted = defFor(MazeAchievementId.gettingStarted);
    final week = defFor(MazeAchievementId.weekOfDevotion);
    final habit = defFor(MazeAchievementId.habitFormed);
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(currentStreak: 1, bestStreak: 7),
      endless: EndlessBestRun(),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(gettingStarted.isUnlocked(inputs), isTrue);
    expect(week.isUnlocked(inputs), isTrue);
    expect(habit.isUnlocked(inputs), isFalse);
  });

  test('endless achievements scale with bestRoundsCleared', () {
    final runner = defFor(MazeAchievementId.enduranceRunner);
    final century = defFor(MazeAchievementId.centuryClub);
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(bestRoundsCleared: 50),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(runner.isUnlocked(inputs), isTrue);
    expect(century.isUnlocked(inputs), isFalse);
    expect(century.progressOf(inputs), closeTo(0.5, 0.001));
  });

  test('progress never exceeds 1.0 even when far past the goal', () {
    final runner = defFor(MazeAchievementId.enduranceRunner);
    const inputs = MazeAchievementInputs(
      progress: MazeProgress(),
      daily: DailyMazeProgress(),
      endless: EndlessBestRun(bestRoundsCleared: 9999),
      ghostLevelsRecorded: 0,
      totalLevels: 10,
    );
    expect(runner.progressOf(inputs), 1.0);
  });

  test('every achievement id is unique', () {
    final ids = kMazeAchievements.map((a) => a.id).toSet();
    expect(ids.length, kMazeAchievements.length);
  });
}
