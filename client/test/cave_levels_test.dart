import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/constants/maze_constants.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/cave_lantern.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';

/// A2 — the two cave levels (Hira and Thawr) opt into cave mode, and doing
/// so leaves them just as solvable as before: the lantern only changes what
/// is *drawn*, never which moves are legal, so the mechanic can't softlock
/// a level. These assertions are what would catch a future change that
/// wires a mechanic into the movement rules by accident.
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel levelById(int id) => kMazeLevels.firstWhere((l) => l.id == id);

  test('exactly the Hira and Thawr levels use cave mode', () {
    final caveLevels = kMazeLevels.where((l) => l.mechanics.hasCave).map((l) => l.id).toList();

    expect(caveLevels, [5, 7]);
  });

  test('no level uses fog mode — fog stays a player setting', () {
    expect(kMazeLevels.where((l) => l.mechanics.hasFog), isEmpty);
  });

  test('no level outside 5 and 7 uses cave mode', () {
    for (final level in kMazeLevels.where((l) => l.id != 5 && l.id != 7)) {
      expect(level.mechanics.hasCave, isFalse, reason: 'level ${level.id}');
    }
  });

  test('the early levels still carry no mechanics at all', () {
    // Levels 1-4 stay deliberately plain so a new player meets one idea at
    // a time; mechanics start at level 5.
    for (final level in kMazeLevels.where((l) => l.id <= 4)) {
      expect(level.mechanics.hasCave, isFalse, reason: 'level ${level.id}');
      expect(level.mechanics.hasFog, isFalse, reason: 'level ${level.id}');
      expect(level.mechanics.hasDoors, isFalse, reason: 'level ${level.id}');
    }
  });

  for (final id in [5, 7]) {
    group('cave level $id', () {
      final level = levelById(id);

      test('is still solvable with cave mode active', () {
        final maze = generator.generate(
          size: level.gridSize,
          seed: level.seed,
          extraLoopCount: level.extraLoopCount,
        );

        final path = solver.shortestPath(maze, maze.start, maze.destination);

        expect(path, isNotNull);
        expect(path!.first, maze.start);
        expect(path.last, maze.destination);
      });

      test('its light orbs all sit on the solution path, off the start/goal', () {
        final maze = generator.generate(
          size: level.gridSize,
          seed: level.seed,
          extraLoopCount: level.extraLoopCount,
        );
        final path = solver.shortestPath(maze, maze.start, maze.destination)!;

        final orbs = CaveLantern.placeOrbs(
          solutionPath: path,
          spacing: MazeConstants.caveOrbSpacing,
          exclude: maze.starCoords.toSet(),
        );

        expect(orbs, isNotEmpty, reason: 'a cave level should offer at least one orb');
        for (final orb in orbs) {
          expect(path, contains(orb));
          expect(orb, isNot(maze.start));
          expect(orb, isNot(maze.destination));
          expect(maze.starCoords, isNot(contains(orb)));
        }
      });

      test('its orb placement is reproducible from the level seed alone', () {
        List<dynamic> orbsFor() {
          final maze = generator.generate(
            size: level.gridSize,
            seed: level.seed,
            extraLoopCount: level.extraLoopCount,
          );
          final path = solver.shortestPath(maze, maze.start, maze.destination)!;
          return CaveLantern.placeOrbs(
            solutionPath: path,
            spacing: MazeConstants.caveOrbSpacing,
            exclude: maze.starCoords.toSet(),
          ).toList();
        }

        expect(orbsFor(), orbsFor());
      });
    });
  }
}
