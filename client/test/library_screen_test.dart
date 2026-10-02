import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/ui/library_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

void main() {
  Future<void> pumpLibrary(WidgetTester tester, Set<int> collected) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeLibraryScreen(collectedFactLevelIds: collected),
    ));
  }

  testWidgets('shows the found count out of the total level count', (tester) async {
    await pumpLibrary(tester, {1, 3, 5});

    expect(find.text('3/${kMazeLevels.length}'), findsOneWidget);
  });

  testWidgets('an unfound level is locked and not tappable', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpLibrary(tester, const {});

    expect(find.bySemanticsLabel(t.mazeLibraryCardLockedSemantics(1)), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(t.mazeLibraryCardLockedSemantics(1)));
    await tester.pump();

    // No fact text should appear since nothing was found/tappable.
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a found level opens its fact in a dialog on tap', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpLibrary(tester, {1});

    expect(find.bySemanticsLabel(t.mazeLibraryCardFoundSemantics(1)), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(t.mazeLibraryCardFoundSemantics(1)));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(t.mazeFactLevel1), findsOneWidget);

    await tester.tap(find.text(t.mazeLibraryCloseButton));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('every level 1-10 renders exactly one card', (tester) async {
    await pumpLibrary(tester, {1, 2, 3});

    for (final level in kMazeLevels) {
      final found = level.id <= 3;
      final t = await AppLocalizations.delegate.load(const Locale('en'));
      final label = found
          ? t.mazeLibraryCardFoundSemantics(level.id)
          : t.mazeLibraryCardLockedSemantics(level.id);
      final finder = find.bySemanticsLabel(label);
      await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable));
      await tester.pump();
      expect(finder, findsOneWidget, reason: 'level ${level.id}');
    }
  });

  testWidgets('the back button pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MazeLibraryScreen(collectedFactLevelIds: {}),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(MazeLibraryScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(MazeLibraryScreen), findsNothing);
  });
}
