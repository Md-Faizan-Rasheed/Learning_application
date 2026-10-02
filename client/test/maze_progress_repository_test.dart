import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_progress_repository.dart';
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
        firstPlayHintShown: true,
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
      expect(loaded.firstPlayHintShown, isTrue);
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
