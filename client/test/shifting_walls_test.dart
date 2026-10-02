import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/doors_and_keys.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/movement_rules.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/shifting_walls.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_passage_edge.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

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

  MazeLevel shiftingLevel() => const MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
        mechanics: MazeMechanics(shiftingWalls: ShiftingWallsConfig()),
      );

  group('ShiftingWalls timing', () {
    ShiftingWalls walls() => ShiftingWalls(
          edges: [MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east)],
          interval: const Duration(seconds: 10),
          warningLead: const Duration(milliseconds: 1500),
        );

    test('starts open', () {
      expect(walls().closedEdges, isEmpty);
    });

    test('alternates: shut for one interval, open for the next', () {
      final w = walls();

      w.tick(const Duration(seconds: 10));
      expect(w.closedEdges, hasLength(1));

      w.tick(const Duration(seconds: 10));
      expect(w.closedEdges, isEmpty);

      w.tick(const Duration(seconds: 10));
      expect(w.closedEdges, hasLength(1));
    });

    test('warns for the configured lead before a flip', () {
      final w = walls();

      w.tick(const Duration(milliseconds: 8000));
      expect(w.warningEdges, isEmpty);

      w.tick(const Duration(milliseconds: 700)); // 8.7s, inside the last 1.5s
      expect(w.warningEdges, hasLength(1));
    });

    test('is a pure function of the clock — same elapsed, same state', () {
      final a = walls()..tick(const Duration(milliseconds: 12345));
      final b = walls()..tick(const Duration(milliseconds: 12345));

      expect(a.closedEdges, b.closedEdges);
      expect(a.warningEdges, b.warningEdges);
    });

    test('reset reopens everything for a replay', () {
      final w = walls()..tick(const Duration(seconds: 10));
      expect(w.closedEdges, hasLength(1));

      w.reset();

      expect(w.closedEdges, isEmpty);
      expect(w.elapsed, Duration.zero);
    });

    test('two toggles are staggered rather than flipping in unison', () {
      final w = ShiftingWalls(
        edges: [
          MazePassageEdge(const MazeCoord(0, 1), MazeDirection.east),
          MazePassageEdge(const MazeCoord(0, 4), MazeDirection.east),
        ],
        interval: const Duration(seconds: 10),
        warningLead: const Duration(milliseconds: 1500),
      );

      // Sample across two full cycles; if they were in lockstep, the set
      // would only ever be empty or full.
      var sawPartial = false;
      for (var ms = 0; ms < 40000; ms += 250) {
        final fresh = ShiftingWalls(
          edges: w.edges,
          interval: const Duration(seconds: 10),
          warningLead: const Duration(milliseconds: 1500),
        )..tick(Duration(milliseconds: ms));
        if (fresh.closedEdges.length == 1) sawPartial = true;
      }

      expect(sawPartial, isTrue);
    });

    test('a frozen state ignores the clock entirely', () {
      final edge = MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east);
      final w = ShiftingWalls.frozen(edges: [edge], closed: {edge});

      w.tick(const Duration(hours: 1));

      expect(w.closedEdges, {edge});
      expect(w.warningEdges, isEmpty);
    });
  });

  group('ShiftingWalls.allStates', () {
    test('enumerates 2^n combinations', () {
      final edges = [
        MazePassageEdge(const MazeCoord(0, 1), MazeDirection.east),
        MazePassageEdge(const MazeCoord(0, 3), MazeDirection.east),
      ];

      final states = ShiftingWalls.allStates(edges);

      // Compared by membership rather than with `contains(someSet)`:
      // Dart's `==` on Set is identity-based, so matching whole sets that
      // way silently fails even when the contents agree.
      expect(states, hasLength(4));
      expect(states.where((s) => s.isEmpty), hasLength(1));
      expect(states.where((s) => s.length == 1 && s.contains(edges[0])), hasLength(1));
      expect(states.where((s) => s.length == 1 && s.contains(edges[1])), hasLength(1));
      expect(states.where((s) => s.length == 2), hasLength(1));
    });

    test('no edges gives exactly one (empty) state', () {
      final states = ShiftingWalls.allStates(const []);

      expect(states, hasLength(1));
      expect(states.single, isEmpty);
    });
  });

  group('blocking movement', () {
    test('a shut passage refuses the move, like a wall', () {
      final maze = corridor(8);
      final edge = MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east);
      final walls = ShiftingWalls.frozen(edges: [edge], closed: {edge});
      final rules = MazeMovementRules(maze: maze, shiftingWalls: walls);

      expect(rules.canPass(const MazeCoord(0, 2), MazeDirection.east), isFalse);
      // And from the other side, thanks to the canonical edge identity.
      expect(rules.canPass(const MazeCoord(0, 3), MazeDirection.west), isFalse);
    });

    test('an open toggle leaves the passage alone', () {
      final maze = corridor(8);
      final edge = MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east);
      final walls = ShiftingWalls.frozen(edges: [edge], closed: const {});
      final rules = MazeMovementRules(maze: maze, shiftingWalls: walls);

      expect(rules.canPass(const MazeCoord(0, 2), MazeDirection.east), isTrue);
    });

    test('a toggle never carves a passage the maze does not have', () {
      final maze = corridor(8);
      // (1,1) has no open sides at all in this corridor maze.
      final edge = MazePassageEdge(const MazeCoord(1, 1), MazeDirection.east);
      final walls = ShiftingWalls.frozen(edges: [edge], closed: const {});
      final rules = MazeMovementRules(maze: maze, shiftingWalls: walls);

      expect(rules.canPass(const MazeCoord(1, 1), MazeDirection.east), isFalse);
    });

    test('the controller treats a shut passage as a bump, not a move', () {
      final maze = corridor(8);
      final edge = MazePassageEdge(maze.start, MazeDirection.east);
      final controller = GameController(
        maze: maze,
        level: shiftingLevel(),
        movement: MazeMovementRules(
          maze: maze,
          shiftingWalls: ShiftingWalls.frozen(edges: [edge], closed: {edge}),
        ),
      );

      expect(controller.move(MazeDirection.east), isFalse);
      expect(controller.playerPosition, maze.start);
    });

    test('walls pause with the game', () {
      final maze = corridor(8);
      final walls = ShiftingWalls(
        edges: [MazePassageEdge(const MazeCoord(0, 2), MazeDirection.east)],
        interval: const Duration(seconds: 10),
        warningLead: const Duration(milliseconds: 1500),
      );
      final controller = GameController(
        maze: maze,
        level: shiftingLevel(),
        movement: MazeMovementRules(maze: maze, shiftingWalls: walls),
      );

      controller.pause();
      controller.tick(const Duration(seconds: 20));
      expect(walls.elapsed, Duration.zero);

      controller.resume();
      controller.tick(const Duration(seconds: 3));
      expect(walls.elapsed, const Duration(seconds: 3));
    });
  });

  group('placeShiftingWalls — the all-states proof', () {
    test('rejects a toggle that would seal a plain corridor', () {
      // In a single corridor every passage is a cut edge, so closing any of
      // them disconnects the goal — nothing is safe to toggle here.
      final maze = corridor(8);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final walls = MazeMovementRules.placeShiftingWalls(
        maze: maze,
        solutionPath: path,
        toggleCount: 1,
        interval: const Duration(seconds: 15),
        warningLead: const Duration(milliseconds: 1500),
      );

      expect(walls.isEmpty, isTrue, reason: 'a corridor has no passage that can safely close');
    });

    test('accepts toggles on a looped maze and proves every state', () {
      // Extra loops give alternate routes, so some passages can safely shut.
      var placedSomewhere = false;
      for (var seed = 1; seed <= 20; seed++) {
        final maze = generator.generate(size: 12, seed: seed, extraLoopCount: 6);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;

        final walls = MazeMovementRules.placeShiftingWalls(
          maze: maze,
          solutionPath: path,
          toggleCount: 2,
          interval: const Duration(seconds: 15),
          warningLead: const Duration(milliseconds: 1500),
        );
        if (walls.isEmpty) continue;
        placedSomewhere = true;

        // Every combination of states must leave the level escapable.
        for (final closed in ShiftingWalls.allStates(walls.edges)) {
          final rules = MazeMovementRules(
            maze: maze,
            shiftingWalls: ShiftingWalls.frozen(edges: walls.edges, closed: closed),
          );
          expect(
            rules.isAlwaysEscapable(),
            isTrue,
            reason: 'seed $seed: state $closed can strand the player',
          );
        }
      }

      expect(placedSomewhere, isTrue, reason: 'looped mazes should offer at least one safe toggle');
    });

    test('a toggle never lands on a passage a locked door already owns', () {
      final maze = generator.generate(size: 12, seed: 5, extraLoopCount: 6);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final doors = DoorsAndKeys.place(maze: maze, solutionPath: path, doorCount: 2);

      final walls = MazeMovementRules.placeShiftingWalls(
        maze: maze,
        solutionPath: path,
        toggleCount: 2,
        interval: const Duration(seconds: 15),
        warningLead: const Duration(milliseconds: 1500),
        doors: doors,
      );

      for (final edge in walls.edges) {
        expect(doors.doors.map((d) => d.edge), isNot(contains(edge)));
      }
    });

    test('placement is deterministic', () {
      final maze = generator.generate(size: 12, seed: 7, extraLoopCount: 6);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      List<MazePassageEdge> run() => MazeMovementRules.placeShiftingWalls(
            maze: maze,
            solutionPath: path,
            toggleCount: 2,
            interval: const Duration(seconds: 15),
            warningLead: const Duration(milliseconds: 1500),
          ).edges;

      expect(run(), run());
    });

    test('asking for zero toggles yields nothing', () {
      final maze = generator.generate(size: 10, seed: 3, extraLoopCount: 4);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final walls = MazeMovementRules.placeShiftingWalls(
        maze: maze,
        solutionPath: path,
        toggleCount: 0,
        interval: const Duration(seconds: 15),
        warningLead: const Duration(milliseconds: 1500),
      );

      expect(walls.isEmpty, isTrue);
    });
  });

  group('level wiring', () {
    test('shifting walls are on levels 9 and 10', () {
      expect(
        kMazeLevels.where((l) => l.mechanics.hasShiftingWalls).map((l) => l.id).toList(),
        [9, 10],
      );
    });

    test('every state of every shifting-wall level stays escapable', () {
      for (final level in kMazeLevels.where((l) => l.mechanics.hasShiftingWalls)) {
        final maze = generator.generate(
          size: level.gridSize,
          seed: level.seed,
          extraLoopCount: level.extraLoopCount,
        );
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final config = level.mechanics.shiftingWalls!;

        final walls = MazeMovementRules.placeShiftingWalls(
          maze: maze,
          solutionPath: path,
          toggleCount: config.toggleCount,
          interval: config.interval,
          warningLead: config.warningLead,
        );

        for (final closed in ShiftingWalls.allStates(walls.edges)) {
          final rules = MazeMovementRules(
            maze: maze,
            shiftingWalls: ShiftingWalls.frozen(edges: walls.edges, closed: closed),
          );
          expect(
            rules.isAlwaysEscapable(),
            isTrue,
            reason: 'level ${level.id}, state $closed strands the player',
          );
        }
      }
    });
  });
}
