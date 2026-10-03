import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/daily_maze_repository.dart';
import 'package:islamic_game/features/seerah_maze/logic/daily/daily_seed.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/ui/daily_maze_play_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C2, end to end: solving the real daily puzzle (driven by real
/// keyboard input, exactly reproducing the same seed the screen itself
/// derives) records a streak day and shows the right outcome message.
void main() {
  const repository = DailyMazeRepository();
  const generator = MazeGenerator();
  const solver = MazeSolver();
  final today = DateTime.utc(2026, 5, 1);

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

  Future<void> solveToday(WidgetTester tester) async {
    final seed = dailySeedFor(today);
    final maze = generator.generate(
      size: DailyMazePlayScreen.gridSize,
      seed: seed,
      extraLoopCount: DailyMazePlayScreen.extraLoopCount,
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
    await tester.pump(const Duration(milliseconds: 750)); // the win pause before any dialog
  }

  testWidgets('solving today\'s maze for the first time starts a streak', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DailyMazePlayScreen(nowUtc: today, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveToday(tester);
    await tester.pump(); // let the save complete and the dialog open
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeDailySolvedTitle), findsOneWidget);
    expect(find.text(t.mazeDailyStreakNote(1)), findsOneWidget);

    final saved = await repository.load();
    expect(saved.currentStreak, 1);
    expect(saved.lastCountedUtcDate, utcDateOnly(today));

    await unmount(tester);
  });

  testWidgets('solving it again the same day shows the practice note, not a new streak day',
      (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await repository.save(DailyMazeProgress(
      currentStreak: 1,
      bestStreak: 1,
      lastCountedUtcDate: utcDateOnly(today),
    ));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DailyMazePlayScreen(nowUtc: today, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveToday(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.mazeDailyPracticeNote), findsOneWidget);

    final saved = await repository.load();
    expect(saved.currentStreak, 1, reason: 'practice runs must not inflate the streak');

    await unmount(tester);
  });

  testWidgets('closing the result dialog returns to the caller', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DailyMazePlayScreen(nowUtc: today, repository: repository),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await solveToday(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(t.mazeLibraryCloseButton));
    // One bare pump flushes the dialog's own pop; the awaited chain back
    // in _onWon then schedules the screen's own pop on a later
    // microtask/frame, so this needs more than a single timed pump to
    // actually complete that second route transition.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(DailyMazePlayScreen), findsNothing);
  });
}
