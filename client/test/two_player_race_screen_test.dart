import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/ui/two_player_race_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C6, end to end: both players race the same generated maze from their
/// own on-screen D-pad, the first to the destination wins, and the race
/// can be restarted or ended from the pause menu.
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  IconData iconFor(MazeDirection direction) => switch (direction) {
        MazeDirection.north => Icons.keyboard_arrow_up_rounded,
        MazeDirection.south => Icons.keyboard_arrow_down_rounded,
        MazeDirection.east => Icons.keyboard_arrow_right_rounded,
        MazeDirection.west => Icons.keyboard_arrow_left_rounded,
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

  /// Replicates the exact seed TwoPlayerRaceScreen's first race draws
  /// from a freshly-seeded `Random(seed)`.
  Future<void> solveViaPad(WidgetTester tester, int randomSeed, String padKey) async {
    final seed = Random(randomSeed).nextInt(1 << 31);
    final maze = generator.generate(
      size: TwoPlayerRaceScreen.gridSize,
      seed: seed,
      extraLoopCount: TwoPlayerRaceScreen.extraLoopCount,
    );
    final path = solver.shortestPath(maze, maze.start, maze.destination)!;
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final direction = MazeDirection.values
          .firstWhere((d) => MazeCoord(from.row + d.deltaRow, from.col + d.deltaCol) == to);
      await tester.tap(find.descendant(
        of: find.byKey(ValueKey(padKey)),
        matching: find.byIcon(iconFor(direction)),
      ));
      await settleMoveTween(tester);
    }
  }

  testWidgets('player 1 reaching the destination first wins the race', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TwoPlayerRaceScreen(random: Random(7)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveViaPad(tester, 7, 'player1Pad');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeRaceWinnerTitle(t.mazePlayerOneLabel)), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('player 2 reaching the destination first wins the race', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TwoPlayerRaceScreen(random: Random(7)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveViaPad(tester, 7, 'player2Pad');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeRaceWinnerTitle(t.mazePlayerTwoLabel)), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('tapping Race Again starts a fresh race without leaving the screen', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TwoPlayerRaceScreen(random: Random(7)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveViaPad(tester, 7, 'player1Pad');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(t.mazeRaceAgainButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(TwoPlayerRaceScreen), findsOneWidget);
    expect(find.text(t.mazeRaceWinnerTitle(t.mazePlayerOneLabel)), findsNothing);

    await unmount(tester);
  });

  testWidgets('pausing then ending the race pops the screen', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TwoPlayerRaceScreen(random: Random(7))),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.mazeQuitButton), findsOneWidget);
    await tester.tap(find.text(t.mazeQuitButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TwoPlayerRaceScreen), findsNothing);
  });
}
