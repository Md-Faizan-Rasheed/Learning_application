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

/// C5 — reverse controls: every keyboard move should land on the
/// opposite cell from the one its key normally points to.
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

Future<void> _settleMoveTween(WidgetTester tester) async {
  const step = Duration(milliseconds: 15);
  var elapsed = Duration.zero;
  final target = MazeConstants.moveTweenDuration + const Duration(milliseconds: 20);
  while (elapsed < target) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _pumpBoard(
  WidgetTester tester,
  GameController controller,
  MazeSolver solver, {
  required bool reverseControlsEnabled,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 360,
          child: MazeBoardWidget(
            controller: controller,
            solver: solver,
            reverseControlsEnabled: reverseControlsEnabled,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  testWidgets('reversed: pressing a key moves the player the opposite way', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver, reverseControlsEnabled: true);

    // The direction that will actually move the player once reversed.
    final trueDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    // The key that has to be pressed to produce that move under reversal.
    final pressedDirection = trueDirection.opposite;

    await tester.sendKeyDownEvent(_keyFor(pressedDirection));
    await _settleMoveTween(tester);
    await tester.sendKeyUpEvent(_keyFor(pressedDirection));

    final expectedCell = MazeCoord(
      maze.start.row + trueDirection.deltaRow,
      maze.start.col + trueDirection.deltaCol,
    );
    expect(controller.playerPosition, expectedCell);
  });

  testWidgets('reversed: pressing the key for the open side does not move the player there',
      (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver, reverseControlsEnabled: true);

    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));
    // Pressing the open direction's own key should NOT move the player
    // that way under reversal — it tries the opposite (closed) side.
    final onlyOpenDirectionExists =
        MazeDirection.values.where((d) => maze.cellAt(maze.start).isOpen(d)).length == 1;
    if (!onlyOpenDirectionExists) return; // ambiguous maze shape for this check; skip

    await tester.sendKeyDownEvent(_keyFor(openDirection));
    await _settleMoveTween(tester);
    await tester.sendKeyUpEvent(_keyFor(openDirection));

    expect(controller.playerPosition, maze.start);
  });

  testWidgets('not reversed: pressing a key moves the player that way, unchanged', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: _testLevel());
    await _pumpBoard(tester, controller, solver, reverseControlsEnabled: false);

    final openDirection = MazeDirection.values.firstWhere((d) => maze.cellAt(maze.start).isOpen(d));

    await tester.sendKeyDownEvent(_keyFor(openDirection));
    await _settleMoveTween(tester);
    await tester.sendKeyUpEvent(_keyFor(openDirection));

    expect(controller.playerPosition, isNot(maze.start));
  });
}
