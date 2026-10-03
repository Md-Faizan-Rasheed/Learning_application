import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/endless_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/logic/endless/endless_round_config.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/ui/endless_play_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C3, end to end: the chained-round bank-countdown structure of Endless
/// mode — solving a round advances and tops up the bank, the bank
/// running dry ends the run, and the pause menu can end it early too.
void main() {
  const repository = EndlessRunRepository();
  const generator = MazeGenerator();
  const solver = MazeSolver();

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
    const target = Duration(milliseconds: 120);
    while (elapsed < target) {
      await tester.pump(step);
      elapsed += step;
    }
  }

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  /// Replicates the exact seed EndlessPlayScreen's own first round will
  /// draw from a freshly-seeded `Random(seed)`, so the test can solve the
  /// real board the screen renders rather than a stand-in.
  Future<void> solveRound(WidgetTester tester, int round, int randomSeed) async {
    final replay = Random(randomSeed);
    for (var i = 1; i < round; i++) {
      replay.nextInt(1 << 31); // advance past earlier rounds' draws
    }
    final seed = replay.nextInt(1 << 31);
    final config = endlessConfigForRound(round);
    final maze = generator.generate(
      size: config.gridSize,
      seed: seed,
      extraLoopCount: config.extraLoopCount,
    );
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
  }

  testWidgets('solving round 1 advances to round 2 and tops up the bank', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EndlessPlayScreen(random: Random(1234), repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(t.mazeEndlessRoundLabel(1)), findsOneWidget);

    await solveRound(tester, 1, 1234);
    // The 500ms win-to-next-round pause, plus settle margin.
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text(t.mazeEndlessRoundLabel(2)), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the bank running out ends the run and shows the tally', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EndlessPlayScreen(random: Random(99), repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Never solve anything — just let the starting bank (60s) run dry.
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeEndlessRunOverTitle), findsOneWidget);
    expect(find.text(t.mazeEndlessRoundsClearedNote(0)), findsOneWidget);

    final saved = await repository.load();
    expect(saved.bestRoundsCleared, 0);

    await tester.tap(find.text(t.mazeLibraryCloseButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(EndlessPlayScreen), findsNothing);
  });

  testWidgets('ending the run from the pause menu reports the current tally', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EndlessPlayScreen(random: Random(42), repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.mazeEndlessEndRunButton), findsOneWidget);
    await tester.tap(find.text(t.mazeEndlessEndRunButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeEndlessRunOverTitle), findsOneWidget);
    expect(find.text(t.mazeEndlessRoundsClearedNote(0)), findsOneWidget);

    await unmount(tester);
  });
}
