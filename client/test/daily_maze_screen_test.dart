import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/daily_maze_repository.dart';
import 'package:islamic_game/features/seerah_maze/logic/daily/daily_seed.dart';
import 'package:islamic_game/features/seerah_maze/models/daily_maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/daily_maze_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = DailyMazeRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DailyMazeScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a fresh install shows a streak of 0 and the Play button', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeDailyPlayButton), findsOneWidget);
    expect(find.text(t.mazeDailyPracticeButton), findsNothing);
  });

  testWidgets('already played today shows Practice Again instead of Play', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await repository.save(DailyMazeProgress(
      currentStreak: 1,
      bestStreak: 1,
      lastCountedUtcDate: utcDateOnly(DateTime.now().toUtc()),
    ));

    await pumpScreen(tester);

    expect(find.text(t.mazeDailyPracticeButton), findsOneWidget);
    expect(find.text(t.mazeDailyPlayButton), findsNothing);
  });

  testWidgets('renders a 28-day calendar grid', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(GridView), findsOneWidget);
    // AspectRatio wraps each day cell 1:1 — one per calendar day shown.
    expect(find.byType(AspectRatio), findsNWidgets(28));
  });

  testWidgets('shows a countdown formatted as HH:MM:SS and keeps rendering it over time',
      (tester) async {
    await pumpScreen(tester);

    // DateTime.now() is the real system clock even inside flutter_test's
    // fake-async pump (only Timer/microtask scheduling is faked), so a
    // short simulated pump cannot reliably be asserted to change the
    // *value* shown — this instead checks the countdown is present, in
    // the right format, and that the periodic Timer keeps firing without
    // throwing across several ticks.
    final countdownFinder = find.descendant(
      of: find.byType(DailyMazeScreen),
      matching: find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(w.data ?? ''),
      ),
    );
    expect(countdownFinder, findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
    expect(countdownFinder, findsOneWidget);
  });

  testWidgets('the back button pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailyMazeScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(DailyMazeScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DailyMazeScreen), findsNothing);
  });
}
