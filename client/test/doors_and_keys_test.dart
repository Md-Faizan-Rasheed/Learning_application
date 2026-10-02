import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/doors_and_keys.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_door.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_passage_edge.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  group('MazePassageEdge canonicalization', () {
    test('the same passage from either side is the same edge', () {
      final fromAbove = MazePassageEdge(const MazeCoord(2, 2), MazeDirection.south);
      final fromBelow = MazePassageEdge(const MazeCoord(3, 2), MazeDirection.north);

      expect(fromAbove, fromBelow);
      expect(fromAbove.hashCode, fromBelow.hashCode);
    });

    test('west/east approaches collapse to the same edge too', () {
      final fromLeft = MazePassageEdge(const MazeCoord(4, 1), MazeDirection.east);
      final fromRight = MazePassageEdge(const MazeCoord(4, 2), MazeDirection.west);

      expect(fromLeft, fromRight);
    });

    test('canonical form always faces east or south', () {
      final edge = MazePassageEdge(const MazeCoord(5, 5), MazeDirection.north);

      expect(edge.direction, anyOf(MazeDirection.east, MazeDirection.south));
      expect(edge.cell, const MazeCoord(4, 5));
    });

    test('connects() recognises both endpoints in either order', () {
      final edge = MazePassageEdge(const MazeCoord(1, 1), MazeDirection.east);

      expect(edge.connects(const MazeCoord(1, 1), const MazeCoord(1, 2)), isTrue);
      expect(edge.connects(const MazeCoord(1, 2), const MazeCoord(1, 1)), isTrue);
      expect(edge.connects(const MazeCoord(1, 1), const MazeCoord(2, 1)), isFalse);
    });

    test('different passages are different edges', () {
      expect(
        MazePassageEdge(const MazeCoord(1, 1), MazeDirection.east),
        isNot(MazePassageEdge(const MazeCoord(1, 1), MazeDirection.south)),
      );
    });
  });

  group('DoorsAndKeys runtime state', () {
    test('a locked door blocks its passage from both sides', () {
      final doors = DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(const MazeCoord(0, 0), MazeDirection.east),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(2, 2): MazeKeyKind.brass},
      );

      expect(doors.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);
      expect(doors.canPass(const MazeCoord(0, 1), MazeDirection.west), isFalse);
    });

    test('holding the key opens it from both sides', () {
      final doors = DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(const MazeCoord(0, 0), MazeDirection.east),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(2, 2): MazeKeyKind.brass},
      );

      doors.collectKeyAt(const MazeCoord(2, 2));

      expect(doors.canPass(const MazeCoord(0, 0), MazeDirection.east), isTrue);
      expect(doors.canPass(const MazeCoord(0, 1), MazeDirection.west), isTrue);
    });

    test('a key only opens doors of its own kind', () {
      final doors = DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(const MazeCoord(0, 0), MazeDirection.east),
            keyKind: MazeKeyKind.silver,
          )
        },
        keys: {const MazeCoord(2, 2): MazeKeyKind.brass},
      );

      doors.collectKeyAt(const MazeCoord(2, 2));

      expect(doors.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);
    });

    test('passages with no door are always passable', () {
      final doors = DoorsAndKeys.none();

      expect(doors.canPass(const MazeCoord(3, 3), MazeDirection.north), isTrue);
      expect(doors.isEmpty, isTrue);
    });

    test('a key can only be picked up once', () {
      final doors = DoorsAndKeys(
        doors: const {},
        keys: {const MazeCoord(1, 1): MazeKeyKind.brass},
      );

      expect(doors.collectKeyAt(const MazeCoord(1, 1)), MazeKeyKind.brass);
      expect(doors.collectKeyAt(const MazeCoord(1, 1)), isNull);
      expect(doors.remainingKeys, isEmpty);
    });

    test('reset re-locks everything for a replay', () {
      final doors = DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(const MazeCoord(0, 0), MazeDirection.east),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(1, 1): MazeKeyKind.brass},
      );
      doors.collectKeyAt(const MazeCoord(1, 1));

      doors.reset();

      expect(doors.heldKeys, isEmpty);
      expect(doors.remainingKeys, hasLength(1));
      expect(doors.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);
      expect(doors.lockedDoors, hasLength(1));
    });
  });

  group('DoorsAndKeys.isSolvable', () {
    test('accepts a layout whose key sits before its door', () {
      final maze = generator.generate(size: 8, seed: 3);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 1);

      expect(
        DoorsAndKeys.isSolvable(maze: maze, doors: placed.doors, keys: placed.keys),
        isTrue,
      );
    });

    test('rejects a door whose key is sealed behind that same door', () {
      final maze = generator.generate(size: 8, seed: 3);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      // Put a door early on the path and hide its key at the destination,
      // which is on the far side of it — the classic softlock.
      final door = MazeDoor(
        edge: MazePassageEdge(path[1], _directionBetween(path[1], path[2])!),
        keyKind: MazeKeyKind.brass,
      );

      expect(
        DoorsAndKeys.isSolvable(
          maze: maze,
          doors: {door},
          keys: {maze.destination: MazeKeyKind.brass},
        ),
        isFalse,
      );
    });

    test('a maze with no doors is trivially solvable', () {
      final maze = generator.generate(size: 6, seed: 1);

      expect(DoorsAndKeys.isSolvable(maze: maze, doors: const {}, keys: const {}), isTrue);
    });

    test('handles a chained dependency (one key behind another door)', () {
      final maze = generator.generate(size: 10, seed: 7);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      // place() only emits layouts it has proven, so whatever ordering it
      // chose — including a chained one — must validate.
      expect(
        DoorsAndKeys.isSolvable(maze: maze, doors: placed.doors, keys: placed.keys),
        isTrue,
      );
    });
  });

  group('DoorsAndKeys.place', () {
    test('places the requested number of doors, each with its own key', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      expect(placed.doors, hasLength(2));
      expect(placed.keys, hasLength(2));
      expect(
        placed.keys.values.toSet(),
        placed.doors.map((d) => d.keyKind).toSet(),
      );
    });

    test('never puts a key on the start, the destination or a star', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      for (final keyCell in placed.keys.keys) {
        expect(keyCell, isNot(maze.start));
        expect(keyCell, isNot(maze.destination));
        expect(maze.starCoords, isNot(contains(keyCell)));
      }
    });

    test('every door sits on a genuinely open passage', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      for (final door in placed.doors) {
        expect(
          maze.cellAt(door.edge.cell).isOpen(door.edge.direction),
          isTrue,
          reason: 'a door on a solid wall would be invisible and pointless',
        );
      }
    });

    test('is deterministic — same maze, same doors and keys', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final a = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);
      final b = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      expect(a.doors, b.doors);
      expect(a.keys, b.keys);
    });

    test('asking for zero or a path too short yields nothing', () {
      final maze = generator.generate(size: 6, seed: 1);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      expect(DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 0).isEmpty, isTrue);
      expect(
        DoorsAndKeys.place(maze: maze, solutionPath: const [], doorCount: 2).isEmpty,
        isTrue,
      );
    });

    test('caps at the number of distinct key kinds rather than overflowing', () {
      final maze = generator.generate(size: 16, seed: 9);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 99);

      expect(placed.doors.length, lessThanOrEqualTo(MazeKeyKind.values.length));
    });

    test('across many seeds, every emitted layout is solvable', () {
      for (var seed = 1; seed <= 40; seed++) {
        final maze = generator.generate(size: 10, seed: seed, extraLoopCount: seed % 3);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;

        for (final count in [1, 2, 3]) {
          final placed = DoorsAndKeys.place(
            maze: maze,
            solutionPath: path,
            doorCount: count,
          );
          expect(
            DoorsAndKeys.isSolvable(maze: maze, doors: placed.doors, keys: placed.keys),
            isTrue,
            reason: 'seed $seed with $count door(s) produced an unsolvable layout',
          );
        }
      }
    });
  });
}

MazeDirection? _directionBetween(MazeCoord from, MazeCoord to) {
  for (final direction in MazeDirection.values) {
    if (from.row + direction.deltaRow == to.row && from.col + direction.deltaCol == to.col) {
      return direction;
    }
  }
  return null;
}
