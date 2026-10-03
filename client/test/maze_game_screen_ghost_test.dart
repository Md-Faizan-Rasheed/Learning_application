import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/ghost_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/ghost_sample.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_board.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C1, end to end through the real MazeGameScreen: finishing a level
/// always saves a ghost, a slower replay never overwrites a faster best,
/// and the "race my best" setting controls whether a stored ghost is
/// actually loaded onto the board.
void main() {
  const repository = GhostRunRepository();
  const generator = MazeGenerator();
  const solver = MazeSolver();
  final level = kMazeLevels.first;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LogicalKeyboardKey keyFor(MazeDirection direction) => switch (direction) {
        MazeDirection.north => LogicalKeyboardKey.arrowUp,
        MazeDirection.south => LogicalKeyboardKey.arrowDown,
        MazeDirection.east => LogicalKeyboardKey.arrowRight,
        MazeDirection.west => LogicalKeyboardKey.arrowLeft,
      };

  Future<void> settleMoveTween(WidgetTester tester) async {
    const step = Duration(milliseconds: 15);
    var elapsed = Duration.zero;
    const target = Duration(milliseconds: 120); // comfortably past the move tween
    while (elapsed < target) {
      await tester.pump(step);
      elapsed += step;
    }
  }

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  /// Drives the real level, via real keyboard input, all the way to the
  /// destination, exactly reproducing what MazeGameScreen itself
  /// generates for [level] (same seed, same generator).
  Future<void> playToWin(WidgetTester tester,
      {MazeProgress progress = const MazeProgress()}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: progress,
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final maze = generator.generate(size: level.gridSize, seed: level.seed);
    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final direction = MazeDirection.values
          .firstWhere((d) => MazeCoord(from.row + d.deltaRow, from.col + d.deltaCol) == to);
      await tester.sendKeyDownEvent(keyFor(direction));
      await settleMoveTween(tester);
      await tester.sendKeyUpEvent(keyFor(direction));
    }
    // _onWon's own 700ms pause before the win card appears.
    await tester.pump(const Duration(milliseconds: 750));
  }

  testWidgets('finishing a level with no prior ghost saves one', (tester) async {
    expect(await repository.loadBest(level.id), isEmpty);

    await playToWin(tester);

    final saved = await repository.loadBest(level.id);
    expect(saved, isNotEmpty);
    expect(saved.first.cell, const MazeCoord(0, 0)); // the start, recorded at t=0
    expect(saved.last.elapsed, greaterThan(Duration.zero));

    await unmount(tester);
  });

  testWidgets('a slower replay never overwrites a faster stored best', (tester) async {
    const fastBest = [
      GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
      GhostSample(elapsed: Duration(milliseconds: 1), cell: MazeCoord(5, 5)),
    ];
    await repository.save(level.id, fastBest);

    // A real playthrough, driven by actual key presses with real pump
    // delays between them, cannot possibly finish in 1ms — so this
    // exercises the real "is the new run faster?" comparison inside
    // MazeGameScreen rather than asserting it in isolation.
    await playToWin(tester);

    final stillStored = await repository.loadBest(level.id);
    expect(stillStored, fastBest, reason: 'the slower real run must not overwrite the 1ms best');

    await unmount(tester);
  });

  testWidgets('a genuinely faster replay does overwrite the stored best', (tester) async {
    const slowBest = [
      GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
      GhostSample(elapsed: Duration(hours: 1), cell: MazeCoord(5, 5)),
    ];
    await repository.save(level.id, slowBest);

    await playToWin(tester);

    final updated = await repository.loadBest(level.id);
    expect(updated, isNot(slowBest));
    expect(updated.last.elapsed, lessThan(const Duration(hours: 1)));

    await unmount(tester);
  });

  testWidgets('racing setting on with a stored ghost loads it onto the board', (tester) async {
    await repository.save(level.id, const [
      GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
    ]);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(raceGhostEnabled: true),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final board = tester.widget<MazeBoardWidget>(find.byType(MazeBoardWidget));
    expect(board.ghostPlayer, isNotNull);
    expect(board.ghostPlayer!.isEmpty, isFalse);

    await unmount(tester);
  });

  testWidgets('racing setting off never loads a ghost onto the board, even if one exists',
      (tester) async {
    await repository.save(level.id, const [
      GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
    ]);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(), // raceGhostEnabled: false
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final board = tester.widget<MazeBoardWidget>(find.byType(MazeBoardWidget));
    expect(board.ghostPlayer, isNull);

    await unmount(tester);
  });
}
