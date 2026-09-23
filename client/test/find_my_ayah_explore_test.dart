import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/screens/find_my_ayah_screen.dart';
import 'package:islamic_game/screens/find_my_ayah_subtree_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Explore tab hosts the constellation, tapping a category star navigates',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FindMyAyahScreen(),
    ));
    await tester.pumpAndSettle();

    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(t.fmaTabExplore));
    // Not pumpAndSettle from here on: ConstellationHero's twinkle animation
    // repeats forever by design (see constellation_hero.dart), so
    // pumpAndSettle would wait for "no more frames scheduled" and time out.
    // A couple of fixed-duration pumps is enough for the tab switch and
    // the tree_page_route.dart zoom transition (420ms) to settle instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FindMyAyahSubTreeScreen), findsNothing);
    final emotionsFinder = find.text('Emotions');
    expect(emotionsFinder, findsOneWidget, reason: 'Emotions star should be on screen');

    await tester.tap(emotionsFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FindMyAyahSubTreeScreen), findsOneWidget,
        reason: 'sub-tree screen should be pushed after tapping a category star');
    expect(find.text('Anxious'), findsOneWidget,
        reason: 'the Emotions sub-tree should show its own situations');

    // Back button should return cleanly to the root screen, reversing the
    // zoom transition rather than leaving the navigator in a stuck state.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FindMyAyahSubTreeScreen), findsNothing);
    expect(find.byType(FindMyAyahScreen), findsOneWidget);
  });
}
