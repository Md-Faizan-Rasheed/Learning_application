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

  testWidgets('Check In tab is the default and opens a card directly, no intermediate nav',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FindMyAyahScreen(),
    ));
    await tester.pumpAndSettle();

    // Check In is the default tab — a situation chip (e.g. "Anxious") is
    // directly on screen without navigating anywhere first. Targeted by
    // key, not label text: the daily featured card can (on some dates)
    // show that same situation's label a second time above the grid.
    final anxiousChip = find.byKey(const ValueKey('checkin_chip_anxiety'));
    expect(anxiousChip, findsOneWidget);
    expect(find.byType(FindMyAyahSubTreeScreen), findsNothing);

    await tester.tap(anxiousChip);
    await tester.pumpAndSettle();

    // Tapping a chip opens the leaf card sheet directly — still no
    // sub-tree screen involved for the Check In path.
    expect(find.byType(FindMyAyahSubTreeScreen), findsNothing);
    expect(find.text('Emotions → Anxious'), findsOneWidget);

    // Close the sheet before the test ends so its route/animation doesn't
    // outlive this test.
    await tester.tap(find.byTooltip(MaterialLocalizations.of(
      tester.element(find.text('Emotions → Anxious')),
    ).closeButtonLabel));
    await tester.pumpAndSettle();
  });
}
