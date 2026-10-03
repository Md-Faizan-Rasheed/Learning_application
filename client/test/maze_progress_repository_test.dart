import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_progress_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_character_skin.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MazeProgressRepository', () {
    test('a fresh install loads the default progress (only level 1 unlocked)', () async {
      const repo = MazeProgressRepository();
      final progress = await repo.load();
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.starsByLevel, isEmpty);
      expect(progress.soundEnabled, isTrue);
    });

    test('saving then loading round-trips every field', () async {
      const repo = MazeProgressRepository();
      const saved = MazeProgress(
        highestUnlockedLevel: 4,
        starsByLevel: {1: 3, 2: 2, 3: 1},
        bestTimeSecondsByLevel: {1: 42, 2: 55},
        soundEnabled: false,
        hapticsEnabled: false,
        joystickEnabled: true,
        fogEnabled: true,
        reduceMotionEnabled: true,
        raceGhostEnabled: true,
        noHintsChallengeEnabled: true,
        reverseControlsEnabled: true,
        firstPlayHintShown: true,
        collectedFactLevelIds: {1, 2},
        noHintsClearedLevelIds: {1, 3},
        selectedSkin: MazeCharacterSkinId.ink,
      );

      await repo.save(saved);
      final loaded = await repo.load();

      expect(loaded.highestUnlockedLevel, 4);
      expect(loaded.starsByLevel, {1: 3, 2: 2, 3: 1});
      expect(loaded.bestTimeSecondsByLevel, {1: 42, 2: 55});
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.hapticsEnabled, isFalse);
      expect(loaded.joystickEnabled, isTrue);
      expect(loaded.fogEnabled, isTrue);
      expect(loaded.reduceMotionEnabled, isTrue);
      expect(loaded.raceGhostEnabled, isTrue);
      expect(loaded.noHintsChallengeEnabled, isTrue);
      expect(loaded.reverseControlsEnabled, isTrue);
      expect(loaded.firstPlayHintShown, isTrue);
      expect(loaded.collectedFactLevelIds, {1, 2});
      expect(loaded.noHintsClearedLevelIds, {1, 3});
      expect(loaded.selectedSkin, MazeCharacterSkinId.ink);
    });

    test('a fresh install defaults to the traveler skin', () async {
      const repo = MazeProgressRepository();
      final progress = await repo.load();
      expect(progress.selectedSkin, MazeCharacterSkinId.traveler);
    });

    test('an unrecognized stored skin name falls back to traveler instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'seerah_maze_progress': '{"selectedSkin": "some_future_skin_this_version_never_heard_of"}',
      });
      const repo = MazeProgressRepository();
      final progress = await repo.load();
      expect(progress.selectedSkin, MazeCharacterSkinId.traveler);
    });

    test('noHintsChallengeEnabled and noHintsClearedLevelIds default safely on a fresh install',
        () async {
      const repo = MazeProgressRepository();
      final progress = await repo.load();
      expect(progress.noHintsChallengeEnabled, isFalse);
      expect(progress.noHintsClearedLevelIds, isEmpty);
    });

    test('corrupted stored data falls back to fresh defaults instead of throwing', () async {
      // Must match MazeProgressRepository's own private storage key.
      SharedPreferences.setMockInitialValues({'seerah_maze_progress': 'not valid json at all'});
      const repo = MazeProgressRepository();

      final progress = await repo.load();

      expect(progress.highestUnlockedLevel, 1);
      expect(progress.starsByLevel, isEmpty);
    });
  });
}
