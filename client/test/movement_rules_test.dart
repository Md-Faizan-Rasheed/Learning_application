import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/doors_and_keys.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/movement_rules.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_door.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_passage_edge.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  /// A corridor along row 0 of a `size`-wide maze, so slide behavior can be
  /// reasoned about exactly rather than inferred from a generated maze.
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
      distancesFromStart: List.generate(
        size,
        (row) => List.generate(size, (col) => row == 0 ? col : -1),
      ),
    );
  }

  group('resolveMove without mechanics', () {
    test('an ordinary step lands on the adjacent cell', () {
      final rules = MazeMovementRules(maze: corridor(6));

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.path, [const MazeCoord(0, 1)]);
      expect(result.landing, const MazeCoord(0, 1));
      expect(result.isSlide, isFalse);
    });

    test('a closed wall is not a legal move', () {
      final rules = MazeMovementRules(maze: corridor(6));

      expect(rules.resolveMove(const MazeCoord(0, 0), MazeDirection.south), isNull);
      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.south), isFalse);
    });

    test('leaving the grid is not a legal move', () {
      final rules = MazeMovementRules(maze: corridor(6));

      expect(rules.resolveMove(const MazeCoord(0, 0), MazeDirection.west), isNull);
    });
  });

  group('slippery sand', () {
    test('slides across a run of sand and stops on solid ground', () {
      final rules = MazeMovementRules(
        maze: corridor(8),
        sandCells: {const MazeCoord(0, 1), const MazeCoord(0, 2), const MazeCoord(0, 3)},
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      // Entered 1,2,3 (all sand) then came to rest on 4, the first solid cell.
      expect(result.path, [
        const MazeCoord(0, 1),
        const MazeCoord(0, 2),
        const MazeCoord(0, 3),
        const MazeCoord(0, 4),
      ]);
      expect(result.landing, const MazeCoord(0, 4));
      expect(result.isSlide, isTrue);
    });

    test('a wall at the end of the sand stops the slide there', () {
      // Sand runs right up to the last cell of the corridor.
      final rules = MazeMovementRules(
        maze: corridor(4),
        sandCells: {const MazeCoord(0, 1), const MazeCoord(0, 2), const MazeCoord(0, 3)},
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.landing, const MazeCoord(0, 3));
    });

    test('a single sand cell followed by solid ground still slides one extra', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        sandCells: {const MazeCoord(0, 1)},
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.landing, const MazeCoord(0, 2));
    });

    test('stepping onto solid ground never slides', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        sandCells: {const MazeCoord(0, 4)},
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.isSlide, isFalse);
      expect(result.landing, const MazeCoord(0, 1));
    });

    test('a locked door stops a slide dead', () {
      final doors = DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(0, 1): MazeKeyKind.brass},
      );
      final rules = MazeMovementRules(
        maze: corridor(8),
        doors: doors,
        sandCells: {const MazeCoord(0, 1), const MazeCoord(0, 2), const MazeCoord(0, 3)},
      );

      // Door sits between (0,2) and (0,3), so the slide halts on (0,2).
      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.landing, const MazeCoord(0, 2));
    });
  });

  group('one-way arrow tiles', () {
    test('an arrow tile can only be left in its own direction', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        oneWayArrows: {const MazeCoord(0, 2): MazeDirection.east},
      );

      expect(rules.canPass(const MazeCoord(0, 2), MazeDirection.east), isTrue);
      expect(rules.canPass(const MazeCoord(0, 2), MazeDirection.west), isFalse);
      expect(rules.resolveMove(const MazeCoord(0, 2), MazeDirection.west), isNull);
    });

    test('an arrow tile can still be entered from any side', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        oneWayArrows: {const MazeCoord(0, 2): MazeDirection.east},
      );

      expect(rules.canPass(const MazeCoord(0, 1), MazeDirection.east), isTrue);
      expect(rules.canPass(const MazeCoord(0, 3), MazeDirection.west), isTrue);
    });

    test('arrowAt reports the tile direction, and null elsewhere', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        oneWayArrows: {const MazeCoord(0, 2): MazeDirection.east},
      );

      expect(rules.arrowAt(const MazeCoord(0, 2)), MazeDirection.east);
      expect(rules.arrowAt(const MazeCoord(0, 3)), isNull);
    });
  });

  group('isAlwaysEscapable — the no-softlock proof', () {
    test('a plain corridor is escapable', () {
      expect(MazeMovementRules(maze: corridor(6)).isAlwaysEscapable(), isTrue);
    });

    test('an arrow pointing away from the goal strands the player', () {
      // The goal is east at (0,5); an arrow at (0,2) forcing west means
      // once you reach it you can never come back east again.
      final rules = MazeMovementRules(
        maze: corridor(6),
        oneWayArrows: {const MazeCoord(0, 2): MazeDirection.west},
      );

      expect(rules.isAlwaysEscapable(), isFalse);
    });

    test('an arrow pointing toward the goal is fine', () {
      final rules = MazeMovementRules(
        maze: corridor(6),
        oneWayArrows: {const MazeCoord(0, 2): MazeDirection.east},
      );

      expect(rules.isAlwaysEscapable(), isTrue);
    });
  });

  group('placement', () {
    test('placeSand only emits layouts that stay escapable', () {
      for (var seed = 1; seed <= 25; seed++) {
        final maze = generator.generate(size: 10, seed: seed, extraLoopCount: seed % 3);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final sand = MazeMovementRules.placeSand(
          maze: maze,
          solutionPath: path,
          patchCount: 2,
          patchLength: 3,
        );

        expect(
          MazeMovementRules(maze: maze, sandCells: sand).isAlwaysEscapable(),
          isTrue,
          reason: 'seed $seed produced sand that can strand the player',
        );
      }
    });

    test('placeOneWays only emits layouts that stay escapable', () {
      for (var seed = 1; seed <= 25; seed++) {
        final maze = generator.generate(size: 10, seed: seed, extraLoopCount: seed % 3);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final arrows = MazeMovementRules.placeOneWays(
          maze: maze,
          solutionPath: path,
          tileCount: 2,
        );

        expect(
          MazeMovementRules(maze: maze, oneWayArrows: arrows).isAlwaysEscapable(),
          isTrue,
          reason: 'seed $seed produced arrows that can strand the player',
        );
      }
    });

    test('sand and arrows together stay escapable', () {
      for (var seed = 1; seed <= 25; seed++) {
        final maze = generator.generate(size: 12, seed: seed, extraLoopCount: seed % 4);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final sand = MazeMovementRules.placeSand(
          maze: maze,
          solutionPath: path,
          patchCount: 2,
          patchLength: 2,
        );
        final arrows = MazeMovementRules.placeOneWays(
          maze: maze,
          solutionPath: path,
          tileCount: 2,
          sandCells: sand,
        );

        expect(
          MazeMovementRules(maze: maze, sandCells: sand, oneWayArrows: arrows).isAlwaysEscapable(),
          isTrue,
          reason: 'seed $seed: sand + arrows can strand the player',
        );
      }
    });

    test('sand never covers a star or a key, which would be unstoppable-on', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final doors = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      final sand = MazeMovementRules.placeSand(
        maze: maze,
        solutionPath: path,
        patchCount: 3,
        patchLength: 3,
        doors: doors,
      );

      for (final cell in sand) {
        expect(maze.starCoords, isNot(contains(cell)));
        expect(doors.keys.keys, isNot(contains(cell)));
      }
    });

    test('placement is deterministic', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      Set<MazeCoord> sandRun() => MazeMovementRules.placeSand(
            maze: maze,
            solutionPath: path,
            patchCount: 2,
            patchLength: 3,
          );

      expect(sandRun(), sandRun());
    });
  });

  group('GameController with sand', () {
    MazeLevel sandLevel() => const MazeLevel(
          id: 1,
          gridSize: 8,
          seed: 1,
          extraLoopCount: 0,
          starTimeThreshold: Duration(minutes: 5),
          destinationKind: MazeDestinationKind.kaaba,
          usesLightMarker: false,
          mechanics: MazeMechanics(sand: SandConfig()),
        );

    test('a slide moves the player the whole run in one move', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: sandLevel(),
        movement: MazeMovementRules(
          maze: maze,
          sandCells: {const MazeCoord(0, 1), const MazeCoord(0, 2)},
        ),
      );

      expect(controller.move(MazeDirection.east), isTrue);

      expect(controller.playerPosition, const MazeCoord(0, 3));
      expect(controller.lastSlidePath, hasLength(3));
    });

    test('an ordinary step reports no slide path', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: sandLevel(),
        movement: MazeMovementRules(maze: maze),
      );

      controller.move(MazeDirection.east);

      expect(controller.lastSlidePath, isEmpty);
    });

    test('sliding across the destination still wins the level', () {
      final maze = corridor(5); // destination at (0,4)
      final controller = GameController(
        maze: maze,
        level: sandLevel(),
        movement: MazeMovementRules(
          maze: maze,
          sandCells: {
            const MazeCoord(0, 1),
            const MazeCoord(0, 2),
            const MazeCoord(0, 3),
          },
        ),
      );

      controller.move(MazeDirection.east);

      expect(controller.playerPosition, maze.destination);
      expect(controller.isWon, isTrue);
    });
  });

  group('level wiring', () {
    test('sand is on levels 8 and 10; one-way only on 10', () {
      expect(
        kMazeLevels.where((l) => l.mechanics.hasSand).map((l) => l.id).toList(),
        [8, 10],
      );
      expect(
        kMazeLevels.where((l) => l.mechanics.hasOneWay).map((l) => l.id).toList(),
        [10],
      );
    });

    test('every level ships movement rules that are escapable from everywhere', () {
      for (final level in kMazeLevels) {
        final maze = generator.generate(
          size: level.gridSize,
          seed: level.seed,
          extraLoopCount: level.extraLoopCount,
        );
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final doors = level.mechanics.hasDoors
            ? DoorsAndKeys.place(
                maze: maze,
                solutionPath: path,
                doorCount: level.mechanics.doors!.doorCount,
              )
            : null;
        final sand = level.mechanics.sand == null
            ? const <MazeCoord>{}
            : MazeMovementRules.placeSand(
                maze: maze,
                solutionPath: path,
                patchCount: level.mechanics.sand!.patchCount,
                patchLength: level.mechanics.sand!.patchLength,
                doors: doors,
              );
        final arrows = level.mechanics.oneWay == null
            ? const <MazeCoord, MazeDirection>{}
            : MazeMovementRules.placeOneWays(
                maze: maze,
                solutionPath: path,
                tileCount: level.mechanics.oneWay!.tileCount,
                doors: doors,
                sandCells: sand,
              );

        final rules = MazeMovementRules(
          maze: maze,
          doors: doors,
          sandCells: sand,
          oneWayArrows: arrows,
        );

        // With doors, "escapable" is evaluated with keys in hand, which is
        // the state the player reaches them in; the door layout's own
        // solvability is proven separately in doors_and_keys_test.
        for (final key in doors?.keys.keys ?? const <MazeCoord>[]) {
          doors!.collectKeyAt(key);
        }

        expect(
          rules.isAlwaysEscapable(),
          isTrue,
          reason: 'level ${level.id} can strand the player',
        );
      }
    });
  });
}
