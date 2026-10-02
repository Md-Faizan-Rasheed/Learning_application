import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';

void main() {
  const generator = MazeGenerator();

  group('MazeGenerator determinism', () {
    test('the same seed and size produce an identical maze every time', () {
      final a = generator.generate(size: 10, seed: 42);
      final b = generator.generate(size: 10, seed: 42);

      expect(a.start, b.start);
      expect(a.destination, b.destination);
      expect(a.starCoords, b.starCoords);
      for (var row = 0; row < 10; row++) {
        for (var col = 0; col < 10; col++) {
          expect(
            a.cells[row][col].openDirections,
            b.cells[row][col].openDirections,
            reason: 'cell ($row,$col) should carry identical open walls',
          );
        }
      }
    });

    test('a different seed produces a different maze', () {
      final a = generator.generate(size: 10, seed: 1);
      final b = generator.generate(size: 10, seed: 2);

      final anyCellDiffers = List.generate(10, (row) => row).any(
        (row) => List.generate(10, (col) => col).any(
          (col) => a.cells[row][col].openDirections != b.cells[row][col].openDirections,
        ),
      );
      expect(anyCellDiffers, isTrue);
    });

    test('extraLoopCount is itself deterministic for a given seed', () {
      final a = generator.generate(size: 10, seed: 7, extraLoopCount: 4);
      final b = generator.generate(size: 10, seed: 7, extraLoopCount: 4);
      for (var row = 0; row < 10; row++) {
        for (var col = 0; col < 10; col++) {
          expect(a.cells[row][col].openDirections, b.cells[row][col].openDirections);
        }
      }
    });
  });

  group('MazeGenerator produces a perfect, fully-connected maze', () {
    test('every cell is reachable from the start', () {
      const solver = MazeSolver();
      for (final seed in [1, 2, 3, 11, 99]) {
        final maze = generator.generate(size: 8, seed: seed);
        for (var row = 0; row < 8; row++) {
          for (var col = 0; col < 8; col++) {
            final target = maze.cells[row][col].coord;
            final path = solver.shortestPath(maze, maze.start, target);
            expect(path, isNotNull, reason: 'cell $target unreachable for seed $seed');
          }
        }
      }
    });

    test(
        'without extra loops, exactly one wall opening exists per adjacent pair '
        '(a spanning tree: size*size - 1 total openings, counted once per pair)', () {
      final maze = generator.generate(size: 8, seed: 5);
      var openPairs = 0;
      for (var row = 0; row < 8; row++) {
        for (var col = 0; col < 8; col++) {
          final cell = maze.cells[row][col];
          if (cell.isOpen(MazeDirection.east)) openPairs++;
          if (cell.isOpen(MazeDirection.south)) openPairs++;
        }
      }
      expect(openPairs, 8 * 8 - 1);
    });

    test('extraLoopCount adds exactly that many openings beyond the spanning tree', () {
      const size = 9;
      final perfect = generator.generate(size: size, seed: 3);
      final withLoops = generator.generate(size: size, seed: 3, extraLoopCount: 5);

      int countOpenPairs(MazeGenerationResult maze) {
        var count = 0;
        for (var row = 0; row < size; row++) {
          for (var col = 0; col < size; col++) {
            final cell = maze.cells[row][col];
            if (cell.isOpen(MazeDirection.east)) count++;
            if (cell.isOpen(MazeDirection.south)) count++;
          }
        }
        return count;
      }

      expect(countOpenPairs(withLoops), countOpenPairs(perfect) + 5);
    });
  });

  group('MazeGenerator destination placement', () {
    test('the destination is the single farthest cell by BFS distance from the start', () {
      const solver = MazeSolver();
      for (final seed in [1, 4, 8, 15]) {
        final maze = generator.generate(size: 9, seed: seed);
        final destinationDistance = solver.distance(maze, maze.start, maze.destination);

        for (var row = 0; row < 9; row++) {
          for (var col = 0; col < 9; col++) {
            final other = maze.cells[row][col].coord;
            final otherDistance = solver.distance(maze, maze.start, other);
            expect(
              otherDistance,
              lessThanOrEqualTo(destinationDistance),
              reason: 'no cell should be farther from the start than the destination',
            );
          }
        }
      }
    });

    test('the destination is never the start itself for a non-trivial maze', () {
      final maze = generator.generate(size: 6, seed: 1);
      expect(maze.destination, isNot(maze.start));
    });
  });

  group('MazeGenerator star placement', () {
    test('stars sit only on dead-end cells, never on the start or destination', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final maze = generator.generate(size: 10, seed: seed);
        for (final star in maze.starCoords) {
          expect(star, isNot(maze.start));
          expect(star, isNot(maze.destination));
          expect(maze.cellAt(star).openDirections.length, 1);
        }
      }
    });

    test('up to 3 stars are placed when enough dead ends exist', () {
      final maze = generator.generate(size: 12, seed: 8);
      expect(maze.starCoords.length, lessThanOrEqualTo(3));
      expect(maze.starCoords.toSet().length, maze.starCoords.length,
          reason: 'star positions must be unique');
    });
  });
}
