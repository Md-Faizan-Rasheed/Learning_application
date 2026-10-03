import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/daily_maze_screen.dart';
import 'package:islamic_game/features/seerah_maze/ui/endless_home_screen.dart';
import 'package:islamic_game/features/seerah_maze/ui/mode_picker_screen.dart';
import 'package:islamic_game/features/seerah_maze/ui/two_player_race_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeModePickerScreen(),
    ));
  }

  testWidgets('shows the Daily Maze card', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeDailyTitle), findsOneWidget);
    expect(find.text(t.mazeModeDailySubtitle), findsOneWidget);
  });

  testWidgets('shows the Endless card', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeEndlessTitle), findsOneWidget);
    expect(find.text(t.mazeModeEndlessSubtitle), findsOneWidget);
  });

  testWidgets('tapping the Endless card navigates to EndlessHomeScreen', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    await tester.tap(find.text(t.mazeEndlessTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(EndlessHomeScreen), findsOneWidget);
  });

  testWidgets('shows the 2-Player Race card', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeTwoPlayerTitle), findsOneWidget);
    expect(find.text(t.mazeModeTwoPlayerSubtitle), findsOneWidget);
  });

  testWidgets('tapping the 2-Player Race card navigates to TwoPlayerRaceScreen', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    await tester.tap(find.text(t.mazeTwoPlayerTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TwoPlayerRaceScreen), findsOneWidget);
  });

  testWidgets('tapping the Daily Maze card navigates to DailyMazeScreen', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    await tester.tap(find.text(t.mazeDailyTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DailyMazeScreen), findsOneWidget);
  });

  testWidgets('the back button pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MazeModePickerScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(MazeModePickerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(MazeModePickerScreen), findsNothing);
  });

  testWidgets('adapts to a wide window without overflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
  });
}
