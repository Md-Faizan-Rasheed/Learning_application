import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';

void main() {
  group('MazeProgress.collectedFactLevelIds persistence', () {
    test('defaults to empty', () {
      expect(const MazeProgress().collectedFactLevelIds, isEmpty);
    });

    test('copyWith replaces the set', () {
      final progress = const MazeProgress().copyWith(collectedFactLevelIds: {1, 5, 8});

      expect(progress.collectedFactLevelIds, {1, 5, 8});
    });

    test('round-trips through JSON', () {
      final original = const MazeProgress().copyWith(collectedFactLevelIds: {2, 4, 6});

      final restored = MazeProgress.fromJson(original.toJson());

      expect(restored.collectedFactLevelIds, original.collectedFactLevelIds);
    });

    test('an old save with no collectedFactLevelIds key migrates to empty', () {
      final restored = MazeProgress.fromJson({'highestUnlockedLevel': 3});

      expect(restored.collectedFactLevelIds, isEmpty);
      expect(restored.highestUnlockedLevel, 3);
    });

    test('non-int entries in the list are dropped rather than crashing', () {
      final restored = MazeProgress.fromJson({
        'collectedFactLevelIds': [1, 'two', 3, null],
      });

      expect(restored.collectedFactLevelIds, {1, 3});
    });

    test('a corrupted (non-list) value for just this field is tolerated', () {
      final restored = MazeProgress.fromJson({
        'highestUnlockedLevel': 7,
        'collectedFactLevelIds': 'not a list',
      });

      expect(restored.collectedFactLevelIds, isEmpty);
      expect(restored.highestUnlockedLevel, 7);
    });
  });
}
