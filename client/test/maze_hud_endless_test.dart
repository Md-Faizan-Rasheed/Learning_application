import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/hud.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C3 — MazeHud's Endless time-bank pill: hidden with no bank to show,
/// otherwise reading "{n}s" and turning the warning color once low.
void main() {
  Future<void> pumpHud(WidgetTester tester, {Duration? bankRemaining}) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MazeHud(
          levelName: 'Round 3',
          elapsed: Duration.zero,
          starsCollected: 0,
          onBack: () {},
          onHint: () {},
          onPause: () {},
          bankRemaining: bankRemaining,
        ),
      ),
    ));
  }

  testWidgets('shows nothing when there is no bank', (tester) async {
    await pumpHud(tester);

    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsNothing);
  });

  testWidgets('shows the remaining seconds', (tester) async {
    await pumpHud(tester, bankRemaining: const Duration(seconds: 42));

    expect(find.text('42s'), findsOneWidget);
  });

  testWidgets('works in the vertical side-panel layout too', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 104,
          child: MazeHud(
            levelName: 'Round 3',
            elapsed: Duration.zero,
            starsCollected: 0,
            axis: Axis.vertical,
            onBack: () {},
            onHint: () {},
            onPause: () {},
            bankRemaining: const Duration(seconds: 7),
          ),
        ),
      ),
    ));

    expect(find.text('7s'), findsOneWidget);
  });

  testWidgets('does not overflow with every HUD element shown at once', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 104,
          child: MazeHud(
            levelName: 'Round 30',
            elapsed: const Duration(minutes: 5, seconds: 30),
            starsCollected: 3,
            axis: Axis.vertical,
            onBack: () {},
            onHint: () {},
            onPause: () {},
            bankRemaining: const Duration(seconds: 3),
            ghostDeltaSeconds: -1.5,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
