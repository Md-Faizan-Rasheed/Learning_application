import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/fog_of_discovery.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

void main() {
  FogOfDiscovery fogWith({double radius = 2.5}) =>
      FogOfDiscovery(config: FogConfig(visibilityRadius: radius));

  group('FogOfDiscovery.reveal', () {
    test('lights every cell within the radius and nothing beyond it', () {
      final fog = fogWith(radius: 1.0);
      fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);

      // Radius 1.0 covers the cell itself and its 4 orthogonal neighbours,
      // but not the diagonals (distance sqrt(2) ~= 1.41).
      expect(fog.rememberedCells, {
        const MazeCoord(5, 5),
        const MazeCoord(4, 5),
        const MazeCoord(6, 5),
        const MazeCoord(5, 4),
        const MazeCoord(5, 6),
      });
    });

    test('a radius past 1.41 pulls in the diagonals too', () {
      final fog = fogWith(radius: 1.5);
      fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);

      expect(fog.rememberedCells, contains(const MazeCoord(4, 4)));
      expect(fog.rememberedCells.length, 9); // the full 3x3 block
    });

    test('never reveals cells outside the grid', () {
      final fog = fogWith(radius: 3);
      fog.reveal(playerPosition: const MazeCoord(0, 0), mazeSize: 6);

      for (final coord in fog.rememberedCells) {
        expect(coord.row, inInclusiveRange(0, 5));
        expect(coord.col, inInclusiveRange(0, 5));
      }
    });

    test('returns only the cells newly revealed by that step', () {
      final fog = fogWith(radius: 1.0);
      final first = fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);
      final second = fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);

      expect(first, isNotEmpty);
      expect(second, isEmpty, reason: 'standing still reveals nothing new');
    });

    test('remembered cells accumulate across moves and are never forgotten', () {
      final fog = fogWith(radius: 1.0);
      fog.reveal(playerPosition: const MazeCoord(1, 1), mazeSize: 12);
      fog.reveal(playerPosition: const MazeCoord(8, 8), mazeSize: 12);

      expect(fog.rememberedCells, contains(const MazeCoord(1, 1)));
      expect(fog.rememberedCells, contains(const MazeCoord(8, 8)));
    });
  });

  group('FogOfDiscovery.visibilityOf', () {
    test('a cell inside the radius is lit', () {
      final fog = fogWith(radius: 2);
      fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);

      expect(
        fog.visibilityOf(const MazeCoord(5, 6), playerPosition: const MazeCoord(5, 5)),
        FogVisibility.lit,
      );
    });

    test('a cell lit earlier but now out of range is remembered, not hidden', () {
      final fog = fogWith(radius: 1);
      fog.reveal(playerPosition: const MazeCoord(5, 5), mazeSize: 12);

      expect(
        fog.visibilityOf(const MazeCoord(5, 5), playerPosition: const MazeCoord(9, 9)),
        FogVisibility.remembered,
      );
    });

    test('a cell never lit is hidden', () {
      final fog = fogWith(radius: 1);
      fog.reveal(playerPosition: const MazeCoord(0, 0), mazeSize: 12);

      expect(
        fog.visibilityOf(const MazeCoord(9, 9), playerPosition: const MazeCoord(0, 0)),
        FogVisibility.hidden,
      );
    });

    test('a radius override (the cave lantern boost) widens what counts as lit', () {
      final fog = fogWith(radius: 1);
      const far = MazeCoord(5, 8);
      const player = MazeCoord(5, 5);

      expect(fog.visibilityOf(far, playerPosition: player), FogVisibility.hidden);
      expect(
        fog.visibilityOf(far, playerPosition: player, radiusOverride: 4),
        FogVisibility.lit,
      );
    });
  });

  group('FogOfDiscovery.veilFor', () {
    test('maps each visibility band to its configured strength', () {
      final fog = FogOfDiscovery(
        config: const FogConfig(rememberedOpacity: 0.5, hiddenOpacity: 0.9),
      );

      expect(fog.veilFor(FogVisibility.lit), 0);
      expect(fog.veilFor(FogVisibility.remembered), 0.5);
      expect(fog.veilFor(FogVisibility.hidden), 0.9);
    });
  });

  test('reset clears the remembered map so a replay starts dark again', () {
    final fog = fogWith();
    fog.reveal(playerPosition: const MazeCoord(3, 3), mazeSize: 12);
    expect(fog.rememberedCells, isNotEmpty);

    fog.reset();

    expect(fog.rememberedCells, isEmpty);
  });

  test('revealing is a pure function of position — same walk, same map', () {
    final a = fogWith();
    final b = fogWith();
    for (final coord in [const MazeCoord(0, 0), const MazeCoord(0, 1), const MazeCoord(1, 1)]) {
      a.reveal(playerPosition: coord, mazeSize: 10);
      b.reveal(playerPosition: coord, mazeSize: 10);
    }

    expect(a.rememberedCells, b.rememberedCells);
  });
}
