import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/daily_maze_repository.dart';
import 'package:islamic_game/features/seerah_maze/data/endless_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_progress_repository.dart';
import 'package:islamic_game/features/seerah_maze/logic/achievements/achievement_text.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/models/endless_best_run.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_achievement.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/achievements_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D1 — the Achievements screen itself: it has no repositories of its
/// own to inject, so these tests seed the real repositories it reads
/// from (same ones C1-C4 already use) via SharedPreferences.setMockInitialValues.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeAchievementsScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a fresh install shows 0 unlocked and every tile locked', (tester) async {
    await pumpScreen(tester);

    expect(find.text('0/${kMazeAchievements.length}'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('an unlocked achievement shows its checkmark and title', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await const MazeProgressRepository().save(
      const MazeProgress(starsByLevel: {1: 1}),
    );

    await pumpScreen(tester);

    final text = mazeAchievementTextFor(t, MazeAchievementId.firstSteps);
    expect(find.text(text.title), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('1/${kMazeAchievements.length}'), findsOneWidget);
  });

  testWidgets('reads daily streak and endless data too, not just campaign progress',
      (tester) async {
    await const DailyMazeRepository().save(
      const DailyMazeProgress(currentStreak: 30, bestStreak: 30),
    );
    await const EndlessRunRepository().save(
      const EndlessBestRun(bestRoundsCleared: 100),
    );

    await pumpScreen(tester);

    // gettingStarted + weekOfDevotion + habitFormed (streak) and
    // enduranceRunner + centuryClub (endless) all clear at these values.
    expect(find.text('5/${kMazeAchievements.length}'), findsOneWidget);
  });

  testWidgets('the back button pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MazeAchievementsScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MazeAchievementsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MazeAchievementsScreen), findsNothing);
  });
}
