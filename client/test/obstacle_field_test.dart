import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/movement_rules.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/obstacle_field.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

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

  MazeLevel caravanLevel({int pushBack = 2}) => MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: const Duration(minutes: 5),
        destinationKind: MazeDestinationKind.caravan,
        usesLightMarker: false,
        mechanics: MazeMechanics(caravans: CaravanConfig(pushBackCells: pushBack)),
      );

  group('CaravanRoute.positionAt', () {
    final route = CaravanRoute(
      segment: const [MazeCoord(0, 1), MazeCoord(0, 2), MazeCoord(0, 3)],
      cycle: const Duration(seconds: 4), // span 2 -> 4 steps -> 1s per step
    );

    test('starts at the first cell of the segment', () {
      expect(route.positionAt(Duration.zero), const MazeCoord(0, 1));
    });

    test('walks out to the far end then back again', () {
      expect(route.positionAt(const Duration(seconds: 1)), const MazeCoord(0, 2));
      expect(route.positionAt(const Duration(seconds: 2)), const MazeCoord(0, 3));
      expect(route.positionAt(const Duration(seconds: 3)), const MazeCoord(0, 2));
    });

    test('loops: one full cycle later it is back where it started', () {
      expect(route.positionAt(const Duration(seconds: 4)), const MazeCoord(0, 1));
      expect(route.positionAt(const Duration(seconds: 8)), const MazeCoord(0, 1));
    });

    test('is a pure function of time — same instant, same cell', () {
      const at = Duration(milliseconds: 2500);

      expect(route.positionAt(at), route.positionAt(at));
    });

    test('never leaves its segment, across a long run of samples', () {
      for (var ms = 0; ms < 20000; ms += 83) {
        expect(route.segment, contains(route.positionAt(Duration(milliseconds: ms))));
      }
    });

    test('reports facing, so the sprite does not walk backwards', () {
      expect(route.isForwardAt(const Duration(seconds: 1)), isTrue);
      expect(route.isForwardAt(const Duration(seconds: 3)), isFalse);
    });
  });

  group('SandstormSchedule', () {
    final schedule = SandstormSchedule(
      candidates: const [MazeCoord(0, 2), MazeCoord(0, 4)],
      period: const Duration(seconds: 10),
      blockedDuration: const Duration(seconds: 4),
      warningLead: const Duration(seconds: 1),
    );

    test('is clear early in the cycle', () {
      expect(schedule.blockedAt(Duration.zero), isNull);
      expect(schedule.warningAt(Duration.zero), isNull);
      expect(schedule.blockedAt(const Duration(seconds: 3)), isNull);
    });

    test('warns for exactly the second before closing', () {
      // Blocked window starts at 10-4 = 6s; warning runs 5s..6s.
      expect(schedule.warningAt(const Duration(seconds: 5)), const MazeCoord(0, 2));
      expect(schedule.warningAt(const Duration(milliseconds: 5999)), const MazeCoord(0, 2));
      expect(schedule.warningAt(const Duration(seconds: 6)), isNull);
    });

    test('blocks for the configured duration, then clears', () {
      expect(schedule.blockedAt(const Duration(seconds: 6)), const MazeCoord(0, 2));
      expect(schedule.blockedAt(const Duration(milliseconds: 9999)), const MazeCoord(0, 2));
      // Next cycle begins: clear again.
      expect(schedule.blockedAt(const Duration(seconds: 10)), isNull);
    });

    test('the warning always names the cell that then actually closes', () {
      for (var ms = 0; ms < 60000; ms += 97) {
        final warned = schedule.warningAt(Duration(milliseconds: ms));
        if (warned == null) continue;
        // One second later, that exact cell is the one blocked.
        final then = schedule.blockedAt(Duration(milliseconds: ms + 1000));
        expect(then, warned, reason: 'warning at ${ms}ms did not match the closure');
      }
    });

    test('rotates between candidates across cycles', () {
      final first = schedule.blockedAt(const Duration(seconds: 7));
      final second = schedule.blockedAt(const Duration(seconds: 17));

      expect(first, const MazeCoord(0, 2));
      expect(second, const MazeCoord(0, 4));
    });

    test('is deterministic', () {
      const at = Duration(milliseconds: 7321);

      expect(schedule.blockedAt(at), schedule.blockedAt(at));
    });
  });

  group('ObstacleField clock', () {
    ObstacleField field() => ObstacleField(
          caravans: [
            CaravanRoute(
              segment: const [MazeCoord(0, 1), MazeCoord(0, 2), MazeCoord(0, 3)],
              cycle: const Duration(seconds: 4),
            )
          ],
        );

    test('advances only through tick', () {
      final obstacles = field();

      expect(obstacles.elapsed, Duration.zero);
      obstacles.tick(const Duration(seconds: 1));
      expect(obstacles.elapsed, const Duration(seconds: 1));
    });

    test('caravanCells follows the clock', () {
      final obstacles = field();

      expect(obstacles.caravanCells, {const MazeCoord(0, 1)});
      obstacles.tick(const Duration(seconds: 1));
      expect(obstacles.caravanCells, {const MazeCoord(0, 2)});
    });

    test('reset puts the clock back for a replay', () {
      final obstacles = field();
      obstacles.tick(const Duration(seconds: 3));

      obstacles.reset();

      expect(obstacles.elapsed, Duration.zero);
      expect(obstacles.caravanCells, {const MazeCoord(0, 1)});
    });
  });

  group('caravan collision', () {
    test('walking into a caravan pushes the player back', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        caravans: [
          CaravanRoute(
            // A stationary-at-t=0 caravan sitting on (0,3).
            segment: const [MazeCoord(0, 3), MazeCoord(0, 4)],
            cycle: const Duration(seconds: 10),
          )
        ],
      );
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        movement: MazeMovementRules(maze: maze, obstacles: obstacles),
      );

      // Walk to (0,2) first so there's trail to be pushed back along.
      controller.move(MazeDirection.east); // -> (0,1)
      controller.move(MazeDirection.east); // -> (0,2)
      expect(controller.playerPosition, const MazeCoord(0, 2));

      controller.move(MazeDirection.east); // into the caravan at (0,3)

      expect(controller.lastMoveHitCaravan, isTrue);
      // Pushed 2 cells back along the trail from (0,3).
      expect(controller.playerPosition, const MazeCoord(0, 1));
    });

    test('contact is never a failure — the level is still playable after', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        caravans: [
          CaravanRoute(
            segment: const [MazeCoord(0, 3), MazeCoord(0, 4)],
            cycle: const Duration(seconds: 10),
          )
        ],
      );
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        movement: MazeMovementRules(maze: maze, obstacles: obstacles),
      );
      controller.move(MazeDirection.east);
      controller.move(MazeDirection.east);
      controller.move(MazeDirection.east); // bump

      expect(controller.isWon, isFalse);
      // Still free to move afterwards.
      expect(controller.move(MazeDirection.east), isTrue);
    });

    test('a pushback at the very start simply leaves the player put', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        caravans: [
          CaravanRoute(
            segment: const [MazeCoord(0, 1), MazeCoord(0, 2)],
            cycle: const Duration(seconds: 10),
          )
        ],
      );
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        movement: MazeMovementRules(maze: maze, obstacles: obstacles),
      );

      controller.move(MazeDirection.east); // straight into the caravan

      expect(controller.lastMoveHitCaravan, isTrue);
      expect(controller.playerPosition, maze.start);
    });

    test('an ordinary move clears the bump flag', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        movement: MazeMovementRules(maze: maze),
      );

      controller.move(MazeDirection.east);

      expect(controller.lastMoveHitCaravan, isFalse);
    });
  });

  group('sandstorm blocking', () {
    test('a closed cell cannot be walked into', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        sandstorm: SandstormSchedule(
          candidates: const [MazeCoord(0, 1)],
          period: const Duration(seconds: 10),
          blockedDuration: const Duration(seconds: 4),
          warningLead: const Duration(seconds: 1),
        ),
      );
      final rules = MazeMovementRules(maze: maze, obstacles: obstacles);

      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.east), isTrue);

      obstacles.tick(const Duration(seconds: 7)); // inside the blocked window

      expect(obstacles.blockedCell, const MazeCoord(0, 1));
      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);
    });

    test('the closure clears, so the player is only ever delayed', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        sandstorm: SandstormSchedule(
          candidates: const [MazeCoord(0, 1)],
          period: const Duration(seconds: 10),
          blockedDuration: const Duration(seconds: 4),
          warningLead: const Duration(seconds: 1),
        ),
      );
      final rules = MazeMovementRules(maze: maze, obstacles: obstacles);
      obstacles.tick(const Duration(seconds: 7));
      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);

      obstacles.tick(const Duration(seconds: 4)); // into the next cycle

      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.east), isTrue);
    });

    test('reachability analysis ignores the storm, so hints do not flicker', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        sandstorm: SandstormSchedule(
          candidates: const [MazeCoord(0, 1)],
          period: const Duration(seconds: 10),
          blockedDuration: const Duration(seconds: 4),
          warningLead: const Duration(seconds: 1),
        ),
      );
      final rules = MazeMovementRules(maze: maze, obstacles: obstacles);
      obstacles.tick(const Duration(seconds: 7)); // storm closed on (0,1)

      // Live movement is blocked, but the level is still considered fully
      // reachable, because the closure always lifts.
      expect(rules.canPass(const MazeCoord(0, 0), MazeDirection.east), isFalse);
      expect(rules.reachableFrom(maze.start), contains(maze.destination));
      expect(rules.isAlwaysEscapable(), isTrue);
    });
  });

  group('obstacles pause with the game', () {
    test('a paused controller does not advance the obstacles', () {
      final maze = corridor(8);
      final obstacles = ObstacleField(
        caravans: [
          CaravanRoute(
            segment: const [MazeCoord(0, 3), MazeCoord(0, 4)],
            cycle: const Duration(seconds: 4),
          )
        ],
      );
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        movement: MazeMovementRules(maze: maze, obstacles: obstacles),
      );

      controller.pause();
      controller.tick(const Duration(seconds: 5));

      expect(obstacles.elapsed, Duration.zero, reason: 'a paused game must freeze the caravan');

      controller.resume();
      controller.tick(const Duration(seconds: 2));

      expect(obstacles.elapsed, const Duration(seconds: 2));
    });

    test('obstacles also stop once the level is won', () {
      final maze = corridor(3);
      final obstacles = ObstacleField(
        caravans: [
          CaravanRoute(
            segment: const [MazeCoord(0, 1), MazeCoord(0, 2)],
            cycle: const Duration(seconds: 4),
          )
        ],
      );
      final controller = GameController(
        maze: maze,
        level: caravanLevel(),
        // No obstacle collision in the way of reaching the goal here; the
        // point is just that the clock stops at the win.
        movement: MazeMovementRules(maze: maze),
      );
      controller.move(MazeDirection.east);
      controller.move(MazeDirection.east);
      expect(controller.isWon, isTrue);

      final before = obstacles.elapsed;
      controller.tick(const Duration(seconds: 3));

      expect(obstacles.elapsed, before);
    });
  });

  group('placement', () {
    test('a caravan patrols a straight run of at least 3 cells', () {
      final maze = generator.generate(size: 12, seed: 4);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final routes = ObstacleField.placeCaravans(
        maze: maze,
        solutionPath: path,
        caravanCount: 1,
        cycle: const Duration(seconds: 8),
      );

      for (final route in routes) {
        expect(route.segment.length, greaterThanOrEqualTo(3));
        // Every cell in the run shares a row or a column with the first.
        final first = route.segment.first;
        final sameRow = route.segment.every((c) => c.row == first.row);
        final sameCol = route.segment.every((c) => c.col == first.col);
        expect(sameRow || sameCol, isTrue, reason: 'patrol must be a straight line');
      }
    });

    test('a caravan never patrols the start, destination or a star', () {
      for (var seed = 1; seed <= 20; seed++) {
        final maze = generator.generate(size: 12, seed: seed);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final routes = ObstacleField.placeCaravans(
          maze: maze,
          solutionPath: path,
          caravanCount: 2,
          cycle: const Duration(seconds: 8),
        );

        for (final route in routes) {
          expect(route.segment, isNot(contains(maze.start)));
          expect(route.segment, isNot(contains(maze.destination)));
          for (final star in maze.starCoords) {
            expect(route.segment, isNot(contains(star)));
          }
        }
      }
    });

    test('sandstorm targets are plain two-exit corridor cells', () {
      final maze = generator.generate(size: 12, seed: 8);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final schedule = ObstacleField.placeSandstorm(
        maze: maze,
        solutionPath: path,
        config: const SandstormConfig(),
      );

      expect(schedule, isNotNull);
      for (final cell in schedule!.candidates) {
        expect(maze.cellAt(cell).openDirections.length, 2);
        expect(cell, isNot(maze.start));
        expect(cell, isNot(maze.destination));
      }
    });

    test('placement is deterministic', () {
      final maze = generator.generate(size: 12, seed: 8);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      List<MazeCoord> run() => ObstacleField.placeCaravans(
            maze: maze,
            solutionPath: path,
            caravanCount: 1,
            cycle: const Duration(seconds: 8),
          ).expand((r) => r.segment).toList();

      expect(run(), run());
    });
  });

  group('level wiring', () {
    test('a caravan is on level 4; the sandstorm on level 8', () {
      expect(
        kMazeLevels.where((l) => l.mechanics.hasCaravans).map((l) => l.id).toList(),
        [4],
      );
      expect(
        kMazeLevels.where((l) => l.mechanics.hasSandstorm).map((l) => l.id).toList(),
        [8],
      );
    });

    test('level 4 actually gets a usable patrol from its own seed', () {
      final level = kMazeLevels.firstWhere((l) => l.id == 4);
      final maze = generator.generate(
        size: level.gridSize,
        seed: level.seed,
        extraLoopCount: level.extraLoopCount,
      );
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final routes = ObstacleField.placeCaravans(
        maze: maze,
        solutionPath: path,
        caravanCount: level.mechanics.caravans!.caravanCount,
        cycle: level.mechanics.caravans!.cycle,
      );

      expect(routes, isNotEmpty, reason: 'level 4 should have somewhere to patrol');
    });

    test('level 8 actually gets a sandstorm schedule from its own seed', () {
      final level = kMazeLevels.firstWhere((l) => l.id == 8);
      final maze = generator.generate(
        size: level.gridSize,
        seed: level.seed,
        extraLoopCount: level.extraLoopCount,
      );
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final schedule = ObstacleField.placeSandstorm(
        maze: maze,
        solutionPath: path,
        config: level.mechanics.sandstorm!,
      );

      expect(schedule, isNotNull);
      expect(schedule!.candidates, isNotEmpty);
    });
  });
}
