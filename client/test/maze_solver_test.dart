import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  group('MazeSolver.shortestPath correctness', () {
    test('a path to the player\'s own cell is just that cell', () {
      final maze = generator.generate(size: 6, seed: 1);
      final path = solver.shortestPath(maze, maze.start, maze.start);
      expect(path, [maze.start]);
    });

    test('every step in the returned path crosses an actually-open wall', () {
      final maze = generator.generate(size: 10, seed: 3);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      for (var i = 0; i < path.length - 1; i++) {
        final from = path[i];
        final to = path[i + 1];
        final crossed = MazeDirection.values.any((direction) {
          final expected = MazeCoord(from.row + direction.deltaRow, from.col + direction.deltaCol);
          return expected == to && maze.cellAt(from).isOpen(direction);
        });
        expect(crossed, isTrue, reason: 'step $from -> $to must cross an open wall');
      }
    });

    test('the returned path is the shortest one (matches a brute-force BFS distance check)', () {
      final maze = generator.generate(size: 8, seed: 6);
      // Independent BFS distance computation, not reusing MazeSolver, so
      // this actually checks MazeSolver's answer rather than itself.
      final distances = <MazeCoord, int>{maze.start: 0};
      final queue = [maze.start];
      var head = 0;
      while (head < queue.length) {
        final current = queue[head++];
        for (final direction in MazeDirection.values) {
          if (!maze.cellAt(current).isOpen(direction)) continue;
          final next =
              MazeCoord(current.row + direction.deltaRow, current.col + direction.deltaCol);
          if (distances.containsKey(next)) continue;
          distances[next] = distances[current]! + 1;
          queue.add(next);
        }
      }

      for (final target in distances.keys) {
        final path = solver.shortestPath(maze, maze.start, target)!;
        expect(path.length - 1, distances[target],
            reason: 'path length to $target should match its true BFS distance');
      }
    });

    test('an unreachable target (disconnected coordinate) returns null', () {
      // A single-cell "maze" has no neighbors at all, so any other
      // coordinate is unreachable from it by construction.
      final maze = generator.generate(size: 2, seed: 1);
      const farAway = MazeCoord(50, 50);
      expect(solver.shortestPath(maze, maze.start, farAway), isNull);
    });
  });

  group('MazeSolver.distance', () {
    test('matches shortestPath length minus one', () {
      final maze = generator.generate(size: 7, seed: 2);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      expect(solver.distance(maze, maze.start, maze.destination), path.length - 1);
    });

    test('is -1 for an unreachable target', () {
      final maze = generator.generate(size: 2, seed: 1);
      expect(solver.distance(maze, maze.start, const MazeCoord(50, 50)), -1);
    });
  });
}
