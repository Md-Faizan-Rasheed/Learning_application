import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/screens/find_my_ayah_screen.dart';
import 'package:islamic_game/widgets/constellation_card_grid.dart';
import 'package:islamic_game/widgets/constellation_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('below the breakpoint, Explore renders the card grid, not the radial map',
      (tester) async {
    tester.view.physicalSize = const Size(kConstellationGridBreakpoint - 40, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FindMyAyahScreen(),
    ));
    await tester.pumpAndSettle();

    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(t.fmaTabExplore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ConstellationCardGrid), findsOneWidget);
    expect(find.byType(ConstellationHero), findsNothing);
  });
}
