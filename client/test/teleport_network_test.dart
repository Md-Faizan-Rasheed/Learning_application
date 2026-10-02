import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/movement_rules.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/teleport_network.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  /// A corridor along row 0, as in movement_rules_test — exact enough to
  /// reason about teleports without a generated maze in the way.
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

  MazeLevel teleportLevel() => const MazeLevel(
        id: 1,
        gridSize: 8,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
        mechanics: MazeMechanics(teleports: TeleportConfig()),
      );

  group('MazeTeleportPair', () {
    const pair = MazeTeleportPair(a: MazeCoord(1, 1), b: MazeCoord(5, 5), index: 0);

    test('partnerOf returns the other end, either way round', () {
      expect(pair.partnerOf(const MazeCoord(1, 1)), const MazeCoord(5, 5));
      expect(pair.partnerOf(const MazeCoord(5, 5)), const MazeCoord(1, 1));
    });

    test('partnerOf is null for a cell that is not part of it', () {
      expect(pair.partnerOf(const MazeCoord(3, 3)), isNull);
    });
  });

  group('TeleportNetwork lookup', () {
    test('tentCells lists both ends of every pair', () {
      final network = TeleportNetwork(pairs: const [
        MazeTeleportPair(a: MazeCoord(1, 1), b: MazeCoord(2, 2), index: 0),
        MazeTeleportPair(a: MazeCoord(3, 3), b: MazeCoord(4, 4), index: 1),
      ]);

      expect(network.tentCells, {
        const MazeCoord(1, 1),
        const MazeCoord(2, 2),
        const MazeCoord(3, 3),
        const MazeCoord(4, 4),
      });
    });

    test('partnerFor ignores the cooldown; activePartnerFor respects it', () {
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(1, 1), b: MazeCoord(2, 2), index: 0)],
        cooldown: const Duration(seconds: 1),
      );

      expect(network.activePartnerFor(const MazeCoord(1, 1)), const MazeCoord(2, 2));

      network.startCooldown();

      expect(network.isOnCooldown, isTrue);
      expect(network.activePartnerFor(const MazeCoord(1, 1)), isNull);
      // The pathfinder's view is unaffected, because a cooldown only ever
      // delays a jump the player can still make a moment later.
      expect(network.partnerFor(const MazeCoord(1, 1)), const MazeCoord(2, 2));
    });

    test('the cooldown expires on tick and never goes negative', () {
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(1, 1), b: MazeCoord(2, 2), index: 0)],
        cooldown: const Duration(seconds: 1),
      );
      network.startCooldown();

      network.tick(const Duration(milliseconds: 900));
      expect(network.isOnCooldown, isTrue);

      network.tick(const Duration(hours: 1));
      expect(network.isOnCooldown, isFalse);
    });

    test('reset clears the cooldown for a replay', () {
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(1, 1), b: MazeCoord(2, 2), index: 0)],
        cooldown: const Duration(seconds: 1),
      );
      network.startCooldown();

      network.reset();

      expect(network.isOnCooldown, isFalse);
    });
  });

  group('teleporting through MazeMovementRules', () {
    test('walking onto a tent lands the player at its partner', () {
      final maze = corridor(8);
      final rules = MazeMovementRules(
        maze: maze,
        teleports: TeleportNetwork(pairs: const [
          MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0),
        ]),
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.isTeleport, isTrue);
      expect(result.teleportedFrom, const MazeCoord(0, 1));
      expect(result.landing, const MazeCoord(0, 6));
    });

    test('arriving on a tent does NOT bounce straight back', () {
      final maze = corridor(8);
      final rules = MazeMovementRules(
        maze: maze,
        teleports: TeleportNetwork(pairs: const [
          MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0),
        ]),
      );

      // The jump resolves once and stops; it is not applied recursively,
      // which is what makes ping-pong structurally impossible.
      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.landing, const MazeCoord(0, 6));
      expect(result.path.where((c) => c == const MazeCoord(0, 1)), hasLength(1));
    });

    test('a sand slide that ends on a tent still teleports', () {
      final maze = corridor(10);
      final rules = MazeMovementRules(
        maze: maze,
        sandCells: {const MazeCoord(0, 1), const MazeCoord(0, 2)},
        teleports: TeleportNetwork(pairs: const [
          MazeTeleportPair(a: MazeCoord(0, 3), b: MazeCoord(0, 8), index: 0),
        ]),
      );

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.isTeleport, isTrue);
      expect(result.landing, const MazeCoord(0, 8));
    });

    test('a tent on cooldown is just a cell to stand on', () {
      final maze = corridor(8);
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0)],
        cooldown: const Duration(seconds: 1),
      );
      network.startCooldown();
      final rules = MazeMovementRules(maze: maze, teleports: network);

      final result = rules.resolveMove(const MazeCoord(0, 0), MazeDirection.east)!;

      expect(result.isTeleport, isFalse);
      expect(result.landing, const MazeCoord(0, 1));
    });
  });

  group('wouldBeTrivialShortcut', () {
    test('rejects a pair that cuts the journey below the allowed fraction', () {
      final maze = corridor(11); // solution is 10 moves
      // A tent at (0,1) linked to (0,9) turns a 10-move walk into ~3.
      final network = TeleportNetwork(pairs: const [
        MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 9), index: 0),
      ]);

      expect(
        network.wouldBeTrivialShortcut(
          maze: maze,
          solutionLength: 10,
          minShortcutFraction: 0.6,
        ),
        isTrue,
      );
    });

    test('accepts a pair that barely changes the journey', () {
      final maze = corridor(11);
      // Linking two adjacent-ish cells saves almost nothing.
      final network = TeleportNetwork(pairs: const [
        MazeTeleportPair(a: MazeCoord(0, 2), b: MazeCoord(0, 3), index: 0),
      ]);

      expect(
        network.wouldBeTrivialShortcut(
          maze: maze,
          solutionLength: 10,
          minShortcutFraction: 0.6,
        ),
        isFalse,
      );
    });

    test('a fraction of 1.0 forbids any shortening at all', () {
      final maze = corridor(11);
      final network = TeleportNetwork(pairs: const [
        MazeTeleportPair(a: MazeCoord(0, 2), b: MazeCoord(0, 4), index: 0),
      ]);

      expect(
        network.wouldBeTrivialShortcut(
          maze: maze,
          solutionLength: 10,
          minShortcutFraction: 1.0,
        ),
        isTrue,
      );
    });
  });

  group('TeleportNetwork.place', () {
    test('never emits a pair that trivially skips the maze', () {
      for (var seed = 1; seed <= 25; seed++) {
        final maze = generator.generate(size: 12, seed: seed, extraLoopCount: seed % 3);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final network = TeleportNetwork.place(
          maze: maze,
          solutionLength: path.length - 1,
          pairCount: 2,
          minShortcutFraction: 0.6,
        );

        expect(
          network.wouldBeTrivialShortcut(
            maze: maze,
            solutionLength: path.length - 1,
            minShortcutFraction: 0.6,
          ),
          isFalse,
          reason: 'seed $seed emitted a trivial shortcut',
        );
      }
    });

    test('never places a tent on the start, destination, a star or a reserved cell', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;
      final reserved = {path[2], path[3]};

      final network = TeleportNetwork.place(
        maze: maze,
        solutionLength: path.length - 1,
        pairCount: 2,
        minShortcutFraction: 0.6,
        reserved: reserved,
      );

      for (final cell in network.tentCells) {
        expect(cell, isNot(maze.start));
        expect(cell, isNot(maze.destination));
        expect(maze.starCoords, isNot(contains(cell)));
        expect(reserved, isNot(contains(cell)));
      }
    });

    test('both ends of a pair are distinct cells', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      final network = TeleportNetwork.place(
        maze: maze,
        solutionLength: path.length - 1,
        pairCount: 2,
        minShortcutFraction: 0.6,
      );

      for (final pair in network.pairs) {
        expect(pair.a, isNot(pair.b));
      }
      // And no cell is shared between pairs.
      expect(network.tentCells.length, network.pairs.length * 2);
    });

    test('placement is deterministic', () {
      final maze = generator.generate(size: 12, seed: 5);
      final path = solver.shortestPath(maze, maze.start, maze.destination)!;

      TeleportNetwork run() => TeleportNetwork.place(
            maze: maze,
            solutionLength: path.length - 1,
            pairCount: 2,
            minShortcutFraction: 0.6,
          );

      expect(run().pairs, run().pairs);
    });

    test('asking for zero pairs yields an empty network', () {
      final maze = generator.generate(size: 8, seed: 2);

      final network = TeleportNetwork.place(
        maze: maze,
        solutionLength: 10,
        pairCount: 0,
        minShortcutFraction: 0.6,
      );

      expect(network.isEmpty, isTrue);
    });

    test('a level stays escapable with its tents in place', () {
      for (var seed = 1; seed <= 20; seed++) {
        final maze = generator.generate(size: 12, seed: seed);
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;
        final network = TeleportNetwork.place(
          maze: maze,
          solutionLength: path.length - 1,
          pairCount: 2,
          minShortcutFraction: 0.6,
        );

        expect(
          MazeMovementRules(maze: maze, teleports: network).isAlwaysEscapable(),
          isTrue,
          reason: 'seed $seed: tents can strand the player',
        );
      }
    });
  });

  group('GameController with tents', () {
    test('a jump moves the player and reports where it came from', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: teleportLevel(),
        movement: MazeMovementRules(
          maze: maze,
          teleports: TeleportNetwork(pairs: const [
            MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0),
          ]),
        ),
      );

      expect(controller.move(MazeDirection.east), isTrue);

      expect(controller.playerPosition, const MazeCoord(0, 6));
      expect(controller.lastTeleportFrom, const MazeCoord(0, 1));
    });

    test('an ordinary move clears the teleport marker', () {
      final maze = corridor(8);
      final controller = GameController(
        maze: maze,
        level: teleportLevel(),
        movement: MazeMovementRules(maze: maze),
      );

      controller.move(MazeDirection.east);

      expect(controller.lastTeleportFrom, isNull);
    });

    test('a jump starts the cooldown, so stepping back on does not re-fire', () {
      final maze = corridor(8);
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0)],
        cooldown: const Duration(seconds: 1),
      );
      final controller = GameController(
        maze: maze,
        level: teleportLevel(),
        movement: MazeMovementRules(maze: maze, teleports: network),
      );

      controller.move(MazeDirection.east); // jumps 1 -> 6
      expect(network.isOnCooldown, isTrue);

      // Stepping west then east again would re-enter tent (0,6)'s side;
      // while cooling down it stays an ordinary cell.
      controller.move(MazeDirection.west);
      expect(controller.lastTeleportFrom, isNull);
    });

    test('the cooldown runs on the game tick, so it pauses with the game', () {
      final maze = corridor(8);
      final network = TeleportNetwork(
        pairs: const [MazeTeleportPair(a: MazeCoord(0, 1), b: MazeCoord(0, 6), index: 0)],
        cooldown: const Duration(seconds: 1),
      );
      final controller = GameController(
        maze: maze,
        level: teleportLevel(),
        movement: MazeMovementRules(maze: maze, teleports: network),
      );
      controller.move(MazeDirection.east);

      controller.pause();
      controller.tick(const Duration(seconds: 5));
      expect(network.isOnCooldown, isTrue, reason: 'a paused game must not drain the cooldown');

      controller.resume();
      controller.tick(const Duration(seconds: 2));
      expect(network.isOnCooldown, isFalse);
    });
  });

  test('level wiring: only level 9 has tents, and its layout is valid', () {
    expect(
      kMazeLevels.where((l) => l.mechanics.hasTeleports).map((l) => l.id).toList(),
      [9],
    );

    final level = kMazeLevels.firstWhere((l) => l.id == 9);
    final maze = generator.generate(
      size: level.gridSize,
      seed: level.seed,
      extraLoopCount: level.extraLoopCount,
    );
    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    final config = level.mechanics.teleports!;
    final network = TeleportNetwork.place(
      maze: maze,
      solutionLength: path.length - 1,
      pairCount: config.pairCount,
      minShortcutFraction: config.minShortcutFraction,
      cooldown: config.cooldown,
    );

    expect(network.pairs, isNotEmpty);
    expect(
      network.wouldBeTrivialShortcut(
        maze: maze,
        solutionLength: path.length - 1,
        minShortcutFraction: config.minShortcutFraction,
      ),
      isFalse,
    );
  });
}
