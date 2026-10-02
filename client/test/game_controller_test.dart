import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';

MazeLevel _levelWithThreshold(Duration threshold) => MazeLevel(
      id: 1,
      gridSize: 8,
      seed: 1,
      extraLoopCount: 0,
      starTimeThreshold: threshold,
      destinationKind: MazeDestinationKind.kaaba,
      usesLightMarker: false,
    );

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  group('GameController.move', () {
    test('moves the player when the wall is open, and updates playerPosition', () {
      final maze = generator.generate(size: 8, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      final openDirection =
          MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));

      final moved = controller.move(openDirection);

      expect(moved, isTrue);
      expect(controller.playerPosition, isNot(maze.start));
    });

    test('refuses to move through a closed wall and leaves position unchanged', () {
      final maze = generator.generate(size: 8, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      final closedDirection =
          MazeDirection.values.firstWhere((d) => !maze.cellAt(maze.start).isOpen(d));

      final moved = controller.move(closedDirection);

      expect(moved, isFalse);
      expect(controller.playerPosition, maze.start);
    });

    test('isWon becomes true exactly when the player reaches the destination', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      expect(controller.isWon, isFalse);

      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      for (var i = 1; i < path.length; i++) {
        final from = path[i - 1];
        final to = path[i];
        final direction = MazeDirection.values
            .firstWhere((d) => MazeCoord(from.row + d.deltaRow, from.col + d.deltaCol) == to);
        controller.move(direction);
      }

      expect(controller.isWon, isTrue);
      expect(controller.playerPosition, maze.destination);
    });
  });

  group('GameController.stepToward (drag-follow 3-cell limit)', () {
    test('follows a target within the 3-cell limit, one step at a time', () {
      final maze = generator.generate(size: 10, seed: 4);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      // Pick a target exactly 3 open-path steps away, if the maze is long
      // enough (it will be at size 10).
      final target = path[3];

      final moved = controller.stepToward(solver, target);

      expect(moved, isTrue);
      expect(controller.playerPosition, path[1],
          reason: 'should advance exactly one step toward target');
    });

    test('refuses a target farther than 3 open-path steps away', () {
      final maze = generator.generate(size: 10, seed: 4);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      expect(path.length - 1, greaterThan(4),
          reason: 'need a maze with a long enough path for this test');
      final farTarget = path[4];

      final moved = controller.stepToward(solver, farTarget);

      expect(moved, isFalse);
      expect(controller.playerPosition, maze.start);
    });

    test('no-ops when the target is the player\'s own cell', () {
      final maze = generator.generate(size: 8, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      expect(controller.stepToward(solver, maze.start), isFalse);
    });
  });

  group('GameController.useHint', () {
    test('returns up to 4 upcoming cells and decrements hintsRemaining', () {
      final maze = generator.generate(size: 10, seed: 5);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));

      final hint = controller.useHint(solver);

      expect(hint.length, lessThanOrEqualTo(4));
      expect(hint, isNot(contains(controller.playerPosition)));
      expect(controller.hintsRemaining, 2);
      expect(controller.hintsUsed, 1);
    });

    test('returns nothing once all 3 hints are used, and never goes negative', () {
      final maze = generator.generate(size: 10, seed: 5);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));

      controller.useHint(solver);
      controller.useHint(solver);
      controller.useHint(solver);
      expect(controller.hintsRemaining, 0);

      final exhausted = controller.useHint(solver);
      expect(exhausted, isEmpty);
      expect(controller.hintsUsed, 3);
    });
  });

  group('GameController.rating thresholds', () {
    test('1 star: finished, but neither all stars nor under time', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller = GameController(maze: maze, level: _levelWithThreshold(Duration.zero));
      controller.tick(const Duration(seconds: 5));
      _walkToDestination(controller, solver);

      expect(controller.isWon, isTrue);
      expect(controller.collectedStars.length, lessThan(maze.starCoords.length),
          reason: 'this test assumes the direct path does not sweep every star');
      expect(controller.rating, MazeRating.one);
    });

    test('2 stars: finished under the time threshold, without all collectibles', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(minutes: 10)));
      _walkToDestination(controller, solver);

      expect(controller.rating, MazeRating.two);
    });

    test('2 stars: finished with all collectibles, even over the time threshold', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller = GameController(maze: maze, level: _levelWithThreshold(Duration.zero));
      for (final star in maze.starCoords) {
        controller.collectedStars.add(star);
      }
      controller.tick(const Duration(seconds: 999));
      _walkToDestination(controller, solver);

      expect(controller.rating, MazeRating.two);
    });

    test('3 stars: finished under time with all collectibles', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(minutes: 10)));
      for (final star in maze.starCoords) {
        controller.collectedStars.add(star);
      }
      _walkToDestination(controller, solver);

      expect(controller.rating, MazeRating.three);
    });

    test('using hints does not change the rating', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(minutes: 10)));
      controller.useHint(solver);
      controller.useHint(solver);
      _walkToDestination(controller, solver);

      expect(controller.rating, MazeRating.two);
      expect(controller.hintsUsed, 2);
    });
  });

  group('GameController.tick/pause', () {
    test('does not advance elapsed time while paused', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      controller.pause();
      controller.tick(const Duration(seconds: 5));
      expect(controller.elapsed, Duration.zero);

      controller.resume();
      controller.tick(const Duration(seconds: 5));
      expect(controller.elapsed, const Duration(seconds: 5));
    });

    test('stops advancing once the maze is won', () {
      final maze = generator.generate(size: 6, seed: 1);
      final controller =
          GameController(maze: maze, level: _levelWithThreshold(const Duration(seconds: 60)));
      _walkToDestination(controller, solver);
      final elapsedAtWin = controller.elapsed;

      controller.tick(const Duration(seconds: 10));

      expect(controller.elapsed, elapsedAtWin);
    });
  });
}

void _walkToDestination(GameController controller, MazeSolver solver) {
  final path =
      solver.shortestPath(controller.maze, controller.playerPosition, controller.maze.destination)!;
  for (var i = 1; i < path.length; i++) {
    final from = path[i - 1];
    final to = path[i];
    final direction = MazeDirection.values
        .firstWhere((d) => MazeCoord(from.row + d.deltaRow, from.col + d.deltaCol) == to);
    controller.move(direction);
  }
}
