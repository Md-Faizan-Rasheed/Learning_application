import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';

void main() {
  group('MazeMechanics.introducedTooltips', () {
    test('a plain level (no mechanics) has nothing to introduce', () {
      expect(MazeMechanics.none.introducedTooltips, isEmpty);
    });

    test('each mechanic maps to exactly its own tooltip', () {
      expect(
        const MazeMechanics(cave: CaveConfig()).introducedTooltips,
        {MazeMechanicTooltip.cave},
      );
      expect(
        const MazeMechanics(doors: DoorConfig()).introducedTooltips,
        {MazeMechanicTooltip.doors},
      );
      expect(
        const MazeMechanics(oneWay: OneWayConfig()).introducedTooltips,
        {MazeMechanicTooltip.oneWay},
      );
      expect(
        const MazeMechanics(sand: SandConfig()).introducedTooltips,
        {MazeMechanicTooltip.sand},
      );
      expect(
        const MazeMechanics(teleports: TeleportConfig()).introducedTooltips,
        {MazeMechanicTooltip.teleport},
      );
      expect(
        const MazeMechanics(caravans: CaravanConfig()).introducedTooltips,
        {MazeMechanicTooltip.caravan},
      );
      expect(
        const MazeMechanics(sandstorm: SandstormConfig()).introducedTooltips,
        {MazeMechanicTooltip.sandstorm},
      );
      expect(
        const MazeMechanics(shiftingWalls: ShiftingWallsConfig()).introducedTooltips,
        {MazeMechanicTooltip.shiftingWalls},
      );
    });

    test('fog has no entry in MazeMechanicTooltip at all', () {
      // Fog is a player-opted settings toggle, never something a level
      // springs on someone — so it was deliberately left out of the enum.
      expect(
        MazeMechanicTooltip.values.map((t) => t.name),
        isNot(contains('fog')),
      );
    });

    test('a level combining mechanics introduces all of them at once', () {
      const mechanics = MazeMechanics(
        sand: SandConfig(),
        sandstorm: SandstormConfig(),
      );

      expect(
        mechanics.introducedTooltips,
        {MazeMechanicTooltip.sand, MazeMechanicTooltip.sandstorm},
      );
    });
  });

  group('level wiring: what each level actually introduces', () {
    List<MazeMechanicTooltip> newlyIntroducedAt(int levelId, Set<MazeMechanicTooltip> seenSoFar) {
      final level = kMazeLevels.firstWhere((l) => l.id == levelId);
      return level.mechanics.introducedTooltips.difference(seenSoFar).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
    }

    test('levels 1-3 introduce nothing', () {
      for (final id in [1, 2, 3]) {
        expect(newlyIntroducedAt(id, {}), isEmpty, reason: 'level $id');
      }
    });

    test('level 4 introduces the caravan', () {
      expect(newlyIntroducedAt(4, {}), [MazeMechanicTooltip.caravan]);
    });

    test('level 5 introduces the cave', () {
      expect(newlyIntroducedAt(5, {MazeMechanicTooltip.caravan}), [MazeMechanicTooltip.cave]);
    });

    test('level 6 introduces doors', () {
      expect(
        newlyIntroducedAt(6, {MazeMechanicTooltip.caravan, MazeMechanicTooltip.cave}),
        [MazeMechanicTooltip.doors],
      );
    });

    test('level 7 (cave again) introduces nothing new', () {
      final seen = {
        MazeMechanicTooltip.caravan,
        MazeMechanicTooltip.cave,
        MazeMechanicTooltip.doors,
      };

      expect(newlyIntroducedAt(7, seen), isEmpty);
    });

    test('level 8 introduces sand and the sandstorm together, sand first', () {
      final seen = {
        MazeMechanicTooltip.caravan,
        MazeMechanicTooltip.cave,
        MazeMechanicTooltip.doors,
      };

      expect(
        newlyIntroducedAt(8, seen),
        [MazeMechanicTooltip.sand, MazeMechanicTooltip.sandstorm],
      );
    });

    test('level 9 introduces teleports and shifting walls together', () {
      final seen = {
        MazeMechanicTooltip.caravan,
        MazeMechanicTooltip.cave,
        MazeMechanicTooltip.doors,
        MazeMechanicTooltip.sand,
        MazeMechanicTooltip.sandstorm,
      };

      expect(
        newlyIntroducedAt(9, seen),
        [MazeMechanicTooltip.teleport, MazeMechanicTooltip.shiftingWalls],
      );
    });

    test('level 10 introduces only one-way tiles (sand is already known)', () {
      final seen = {
        MazeMechanicTooltip.caravan,
        MazeMechanicTooltip.cave,
        MazeMechanicTooltip.doors,
        MazeMechanicTooltip.sand,
        MazeMechanicTooltip.sandstorm,
        MazeMechanicTooltip.teleport,
        MazeMechanicTooltip.shiftingWalls,
      };

      expect(newlyIntroducedAt(10, seen), [MazeMechanicTooltip.oneWay]);
    });

    test('playing every level in order, every mechanic is introduced exactly once', () {
      final seen = <MazeMechanicTooltip>{};
      final firstSeenAtLevel = <MazeMechanicTooltip, int>{};

      for (final level in kMazeLevels) {
        final newOnes = level.mechanics.introducedTooltips.difference(seen);
        for (final tooltip in newOnes) {
          firstSeenAtLevel[tooltip] = level.id;
        }
        seen.addAll(newOnes);
      }

      expect(seen, MazeMechanicTooltip.values.toSet());
      // Every mechanic got a first-introduction level — some levels
      // legitimately introduce more than one at once (8: sand + the
      // sandstorm; 9: teleports + shifting walls), so this checks
      // completeness, not that those levels are themselves distinct.
      expect(firstSeenAtLevel.length, MazeMechanicTooltip.values.length);
    });
  });

  group('MazeProgress.seenMechanicTooltips persistence', () {
    test('defaults to empty', () {
      expect(const MazeProgress().seenMechanicTooltips, isEmpty);
    });

    test('copyWith replaces the set', () {
      final progress = const MazeProgress().copyWith(
        seenMechanicTooltips: {MazeMechanicTooltip.cave, MazeMechanicTooltip.doors},
      );

      expect(progress.seenMechanicTooltips, {MazeMechanicTooltip.cave, MazeMechanicTooltip.doors});
    });

    test('round-trips through JSON', () {
      final original = const MazeProgress().copyWith(
        seenMechanicTooltips: {
          MazeMechanicTooltip.cave,
          MazeMechanicTooltip.sand,
          MazeMechanicTooltip.oneWay,
        },
      );

      final restored = MazeProgress.fromJson(original.toJson());

      expect(restored.seenMechanicTooltips, original.seenMechanicTooltips);
    });

    test('an old save with no seenMechanicTooltips key migrates to empty, not a crash', () {
      final restored = MazeProgress.fromJson({
        'highestUnlockedLevel': 6,
        'starsByLevel': {'1': 3},
      });

      expect(restored.seenMechanicTooltips, isEmpty);
      expect(restored.highestUnlockedLevel, 6);
    });

    test('an unknown tooltip name (a future save) is dropped, not a crash', () {
      final restored = MazeProgress.fromJson({
        'seenMechanicTooltips': ['cave', 'someFutureMechanic', 'sand'],
      });

      expect(restored.seenMechanicTooltips, {MazeMechanicTooltip.cave, MazeMechanicTooltip.sand});
    });

    test('a corrupted (non-list) value for just this field is tolerated', () {
      final restored = MazeProgress.fromJson({
        'highestUnlockedLevel': 4,
        'seenMechanicTooltips': 'not a list',
      });

      expect(restored.seenMechanicTooltips, isEmpty);
      // Confirms this didn't trip the top-level catch-and-reset: the rest
      // of the save survived intact alongside the one bad field.
      expect(restored.highestUnlockedLevel, 4);
    });
  });
}
