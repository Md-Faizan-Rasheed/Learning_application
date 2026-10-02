import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/constants/maze_constants.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_board.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

MazeLevel _testLevel() => const MazeLevel(
      id: 1,
      gridSize: 6,
      seed: 1,
      extraLoopCount: 0,
      starTimeThreshold: Duration(minutes: 5),
      destinationKind: MazeDestinationKind.kaaba,
      usesLightMarker: false,
    );

LogicalKeyboardKey _keyFor(MazeDirection direction) => switch (direction) {
      MazeDirection.north => LogicalKeyboardKey.arrowUp,
      MazeDirection.south => LogicalKeyboardKey.arrowDown,
      MazeDirection.east => LogicalKeyboardKey.arrowRight,
      MazeDirection.west => LogicalKeyboardKey.arrowLeft,
    };

/// Advances past one move-tween's duration via several small pumps rather
/// than one big jump. A single `tester.pump(bigDuration)` jump can leave
/// the AnimationController's completed-status callback (which flips
/// `_isAnimatingMove` back to false) un-resolved by the time this returns —
/// a fake-clock test-harness quirk, not something a real device hits
/// (real frames arrive continuously at ~60fps instead of one big jump), but
/// it means tests that chain multiple moves must pump incrementally to
/// match how real frames actually arrive.
Future<void> _settleMoveTween(WidgetTester tester) async {
  const step = Duration(milliseconds: 15);
  var elapsed = Duration.zero;
  final target = MazeConstants.moveTweenDuration + const Duration(milliseconds: 20);
  while (elapsed < target) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _pumpBoard(WidgetTester tester, GameController controller, MazeSolver solver) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 360,
          child: MazeBoardWidget(controller: controller, solver: solver),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  testWidgets('an arrow-key press in an open direction moves the player', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver);

    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));

    await tester.sendKeyDownEvent(_keyFor(openDirection));
    await _settleMoveTween(tester);
    await tester.sendKeyUpEvent(_keyFor(openDirection));

    expect(controller.playerPosition, isNot(maze.start));
  });

  testWidgets('an arrow-key press into a closed wall does not move the player', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver);

    final closedDirection =
        MazeDirection.values.firstWhere((d) => !maze.cellAt(maze.start).isOpen(d));

    await tester.sendKeyDownEvent(_keyFor(closedDirection));
    await _settleMoveTween(tester);
    await tester.sendKeyUpEvent(_keyFor(closedDirection));

    expect(controller.playerPosition, maze.start);
  });

  testWidgets('a drag toward a nearby open cell moves the player via BFS-follow', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver);

    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    final target = path[path.length > 2 ? 2 : 1];
    // Board renders centered in a 360x360 box; cellSize = 360/6 = 60.
    const cellSize = 360.0 / 6;
    final targetCenter = Offset((target.col + 0.5) * cellSize, (target.row + 0.5) * cellSize);

    final gesture = await tester.startGesture(targetCenter);
    await tester.pump(MazeConstants.dragStepThrottle + const Duration(milliseconds: 10));
    await gesture.moveTo(targetCenter);
    await _settleMoveTween(tester);
    await gesture.up();

    expect(controller.playerPosition, isNot(maze.start));
  });

  testWidgets(
      'a drag still targets the right cell when the board is centered inside a taller viewport',
      (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    // A viewport taller than it is wide (closer to a real phone screen) so
    // the square board sits centered with empty space above and below it —
    // regression coverage for a bug where drag input was read in the
    // viewport's coordinate space while hit-testing assumed the board's own,
    // making every drag land on the wrong cell whenever the two didn't
    // already coincide (as they always did in the 360x360 box above).
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: MazeBoardWidget(controller: controller, solver: solver),
          ),
        ),
      ),
    );
    await tester.pump();

    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    final target = path[path.length > 2 ? 2 : 1];
    // Board renders at 360x360 (cellSize = 360/6 = 60), vertically centered
    // in the 600-tall viewport, leaving a (600-360)/2 = 120px gap above it.
    const cellSize = 360.0 / 6;
    const verticalOffset = (600 - 360) / 2;
    final targetCenter =
        Offset((target.col + 0.5) * cellSize, verticalOffset + (target.row + 0.5) * cellSize);

    final gesture = await tester.startGesture(targetCenter);
    await tester.pump(MazeConstants.dragStepThrottle + const Duration(milliseconds: 10));
    await gesture.moveTo(targetCenter);
    await _settleMoveTween(tester);
    await gesture.up();

    expect(controller.playerPosition, isNot(maze.start));
  });

  testWidgets('reaching the destination does not throw and marks the controller won',
      (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver);

    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final direction = MazeDirection.values
          .firstWhere((d) => MazeCoord(from.row + d.deltaRow, from.col + d.deltaCol) == to);
      await tester.sendKeyDownEvent(_keyFor(direction));
      await _settleMoveTween(tester);
      await tester.sendKeyUpEvent(_keyFor(direction));
    }

    expect(controller.isWon, isTrue);
  });
}
