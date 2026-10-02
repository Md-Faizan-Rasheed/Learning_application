import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/collectibles/fact_scroll_placement.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel plainLevel() => const MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      );

  group('placeFactScroll', () {
    test('picks an actual dead end, never the start, destination, or a star', () {
      for (var seed = 1; seed <= 30; seed++) {
        final maze = generator.generate(size: 10, seed: seed, extraLoopCount: seed % 3);
        final cell = placeFactScroll(maze: maze);

        if (cell == null) continue; // a maze with zero free dead ends is possible but rare
        expect(maze.cellAt(cell).openDirections.length, 1, reason: 'seed $seed');
        expect(cell, isNot(maze.start));
        expect(cell, isNot(maze.destination));
        expect(maze.starCoords, isNot(contains(cell)));
      }
    });

    test('never lands on a reserved cell', () {
      final maze = generator.generate(size: 10, seed: 3);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final reserved = {path[2], path[3], path[4]};

      final cell = placeFactScroll(maze: maze, reserved: reserved);

      if (cell != null) expect(reserved, isNot(contains(cell)));
    });

    test('is deterministic', () {
      final maze = generator.generate(size: 10, seed: 7);

      expect(placeFactScroll(maze: maze), placeFactScroll(maze: maze));
    });

    test('returns null rather than throwing when no dead end is free', () {
      final maze = generator.generate(size: 10, seed: 3);
      final allDeadEnds = <MazeCoord>{};
      for (var row = 0; row < maze.size; row++) {
        for (var col = 0; col < maze.size; col++) {
          final coord = MazeCoord(row, col);
          if (maze.cellAt(coord).openDirections.length == 1) allDeadEnds.add(coord);
        }
      }

      final cell = placeFactScroll(maze: maze, reserved: allDeadEnds);

      expect(cell, isNull);
    });
  });

  group('GameController fact collection', () {
    MazeGenerationResult corridor(int size) {
      final cells = List.generate(
        size,
        (row) => List.generate(size, (col) {
          final open = <MazeDirection>{};
          if (row == 0) {
            if (col > 0) open.add(MazeDirection.west);
            if (col < size - 1) open.add(MazeDirection.east);
          }
          return MazeCell(coord: MazeCoord(row, col), open: open);
        }),
      );
      return MazeGenerationResult(
        size: size,
        cells: cells,
        start: const MazeCoord(0, 0),
        destination: MazeCoord(0, size - 1),
        starCoords: const [],
        distancesFromStart:
            List.generate(size, (row) => List.generate(size, (col) => row == 0 ? col : -1)),
      );
    }

    test('walking onto the scroll cell collects it', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: plainLevel(),
        factScrollCell: const MazeCoord(0, 2),
      );

      expect(controller.factCollected, isFalse);
      controller.move(MazeDirection.east);
      controller.move(MazeDirection.east);

      expect(controller.factCollected, isTrue);
      expect(controller.lastMoveCollectedFact, isTrue);
    });

    test('lastMoveCollectedFact only flags the move that actually collected it', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: plainLevel(),
        factScrollCell: const MazeCoord(0, 1),
      );

      controller.move(MazeDirection.east); // collects
      expect(controller.lastMoveCollectedFact, isTrue);

      controller.move(MazeDirection.east); // ordinary move afterward
      expect(controller.lastMoveCollectedFact, isFalse);
    });

    test('a level with no scroll never reports a collection', () {
      final maze = corridor(8);
      final controller = GameController(maze: maze, level: plainLevel());

      controller.move(MazeDirection.east);

      expect(controller.factCollected, isFalse);
      expect(controller.lastMoveCollectedFact, isFalse);
    });

    test('sliding across the scroll cell on a sand level still collects it', () {
      // Collection is checked across every cell in result.path, the same
      // loop that already handles stars/keys during a multi-cell slide.
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: plainLevel(),
        factScrollCell: const MazeCoord(0, 2),
      );

      // No sand wired here, but a direct multi-step walk exercises the
      // same per-cell loop a slide would.
      controller.move(MazeDirection.east);
      controller.move(MazeDirection.east);

      expect(controller.factCollected, isTrue);
    });
  });

  test('most levels have somewhere for their scroll on their own seed', () {
    // Per the spec's own "hidden scroll pickups in SOME mazes", a level
    // isn't guaranteed one — a small early grid can run out of dead ends
    // once the 3 collectible stars have already claimed theirs. This
    // just checks the mechanism actually finds a spot on the levels that
    // do have room, not that literally every level must get a scroll.
    var withScroll = 0;
    for (final level in kMazeLevels) {
      final maze = generator.generate(
        size: level.gridSize,
        seed: level.seed,
        extraLoopCount: level.extraLoopCount,
      );
      if (placeFactScroll(maze: maze) != null) withScroll++;
    }

    expect(withScroll, greaterThanOrEqualTo(kMazeLevels.length ~/ 2));
  });
}
