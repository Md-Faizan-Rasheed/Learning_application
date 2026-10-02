import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/doors_and_keys.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_door.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_passage_edge.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

/// A3's movement side: a locked door has to read exactly like a wall to
/// the controller, and the hint system must never point through one.
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel testLevel() => const MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 3,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
        mechanics: MazeMechanics(doors: DoorConfig()),
      );

  test('a locked door refuses the move, exactly like a closed wall', () {
    final maze = generator.generate(size: 8, seed: 3);
    // Lock whichever direction out of the start is actually open.
    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    final controller = GameController(
      maze: maze,
      level: testLevel(),
      doors: DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(maze.start, openDirection),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(7, 7): MazeKeyKind.brass},
      ),
    );

    expect(controller.move(openDirection), isFalse);
    expect(controller.playerPosition, maze.start);
  });

  test('once the key is held, the same move succeeds', () {
    final maze = generator.generate(size: 8, seed: 3);
    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    final doors = DoorsAndKeys(
      doors: {
        MazeDoor(
          edge: MazePassageEdge(maze.start, openDirection),
          keyKind: MazeKeyKind.brass,
        )
      },
      keys: {const MazeCoord(7, 7): MazeKeyKind.brass},
    );
    final controller = GameController(maze: maze, level: testLevel(), doors: doors);

    doors.collectKeyAt(const MazeCoord(7, 7));

    expect(controller.move(openDirection), isTrue);
    expect(controller.playerPosition, isNot(maze.start));
  });

  test('walking onto a key cell collects it automatically', () {
    final maze = generator.generate(size: 8, seed: 3);
    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    final neighbor = MazeCoord(
      maze.start.row + openDirection.deltaRow,
      maze.start.col + openDirection.deltaCol,
    );
    final controller = GameController(
      maze: maze,
      level: testLevel(),
      doors: DoorsAndKeys(doors: const {}, keys: {neighbor: MazeKeyKind.silver}),
    );

    expect(controller.heldKeys, isEmpty);
    controller.move(openDirection);

    expect(controller.heldKeys, {MazeKeyKind.silver});
  });

  test('drag-follow will not route through a locked door', () {
    final maze = generator.generate(size: 8, seed: 3);
    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    final neighbor = MazeCoord(
      maze.start.row + openDirection.deltaRow,
      maze.start.col + openDirection.deltaCol,
    );
    final controller = GameController(
      maze: maze,
      level: testLevel(),
      doors: DoorsAndKeys(
        doors: {
          MazeDoor(
            edge: MazePassageEdge(maze.start, openDirection),
            keyKind: MazeKeyKind.brass,
          )
        },
        keys: {const MazeCoord(7, 7): MazeKeyKind.brass},
      ),
    );

    expect(controller.stepToward(solver, neighbor), isFalse);
    expect(controller.playerPosition, maze.start);
  });

  test('a hint points toward the key when the goal is sealed off', () {
    final maze = generator.generate(size: 8, seed: 3);
    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    final placed = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 1);
    final controller = GameController(maze: maze, level: testLevel(), doors: placed);

    final hint = controller.useHint(solver);

    expect(hint, isNotEmpty, reason: 'a hint must still offer somewhere to go');
    // Every hinted cell must be somewhere the player can actually walk to
    // right now — i.e. never on the far side of the locked door.
    for (final cell in hint) {
      expect(
        solver.distance(maze, controller.playerPosition, cell, canPass: placed.canPass),
        greaterThanOrEqualTo(0),
      );
    }
  });

  test('levels without the mechanic behave exactly as before', () {
    final maze = generator.generate(size: 8, seed: 3);
    final controller = GameController(
      maze: maze,
      level: const MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 3,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      ),
    );
    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));

    expect(controller.doors.isEmpty, isTrue);
    expect(controller.heldKeys, isEmpty);
    expect(controller.move(openDirection), isTrue);
  });

  group('level wiring', () {
    test('exactly levels 6 and 9 use doors', () {
      final doorLevels = kMazeLevels.where((l) => l.mechanics.hasDoors).map((l) => l.id).toList();

      expect(doorLevels, [6, 9]);
    });

    for (final id in [6, 9]) {
      test('level $id ships a solvable door layout', () {
        final level = kMazeLevels.firstWhere((l) => l.id == id);
        final maze = generator.generate(
          size: level.gridSize,
          seed: level.seed,
          extraLoopCount: level.extraLoopCount,
        );
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final placed = DoorsAndKeys.place(
          maze: maze,
          solutionPath: path,
          doorCount: level.mechanics.doors!.doorCount,
        );

        expect(placed.doors, isNotEmpty);
        expect(
          DoorsAndKeys.isSolvable(maze: maze, doors: placed.doors, keys: placed.keys),
          isTrue,
        );
      });
    }
  });
}
