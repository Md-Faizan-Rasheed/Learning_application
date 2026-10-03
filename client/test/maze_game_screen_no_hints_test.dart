import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C4, end to end through the real MazeGameScreen: the No-Hints
/// Challenge locks the hint button, and finishing a level with it on
/// (and so with zero hints used) records a per-level achievement and
/// shows the win card's badge — but only when the toggle was actually on.
void main() {
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
    const target = Duration(milliseconds: 120);
    while (elapsed < target) {
      await tester.pump(step);
      elapsed += step;
    }
  }

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  Future<MazeProgress> playToWin(
    WidgetTester tester, {
    required MazeProgress initialProgress,
  }) async {
    var latestProgress = initialProgress;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: initialProgress,
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (p) => latestProgress = p,
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
    await tester.pump(const Duration(milliseconds: 750));
    return latestProgress;
  }

  testWidgets('the hint button is locked when the challenge toggle is on', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(noHintsChallengeEnabled: true),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('winning with the challenge on records the achievement and shows the badge',
      (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    final finalProgress = await playToWin(
      tester,
      initialProgress: const MazeProgress(noHintsChallengeEnabled: true),
    );

    expect(finalProgress.noHintsClearedLevelIds, contains(level.id));
    expect(find.text(t.mazeNoHintsChallengeClearedBadge), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('winning with the challenge off neither records nor shows the badge', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    final finalProgress = await playToWin(tester, initialProgress: const MazeProgress());

    expect(finalProgress.noHintsClearedLevelIds, isNot(contains(level.id)));
    expect(find.text(t.mazeNoHintsChallengeClearedBadge), findsNothing);

    await unmount(tester);
  });

  testWidgets('a level already in noHintsClearedLevelIds does not get re-added redundantly',
      (tester) async {
    final finalProgress = await playToWin(
      tester,
      initialProgress: MazeProgress(
        noHintsChallengeEnabled: true,
        noHintsClearedLevelIds: {level.id},
      ),
    );

    expect(finalProgress.noHintsClearedLevelIds, {level.id});

    await unmount(tester);
  });
}
