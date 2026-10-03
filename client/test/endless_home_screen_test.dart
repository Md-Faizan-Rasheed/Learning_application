import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/endless_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/endless_best_run.dart';
import 'package:islamic_game/features/seerah_maze/ui/endless_home_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = EndlessRunRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EndlessHomeScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a fresh install shows no runs yet', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeEndlessHomeBestLabel(0)), findsOneWidget);
    expect(find.text(t.mazeEndlessStartButton), findsOneWidget);
  });

  testWidgets('shows a previously saved best run', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await repository.save(const EndlessBestRun(bestRoundsCleared: 8));

    await pumpScreen(tester);

    expect(find.text(t.mazeEndlessHomeBestLabel(8)), findsOneWidget);
  });

  testWidgets('the back button pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EndlessHomeScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(EndlessHomeScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(EndlessHomeScreen), findsNothing);
  });
}
