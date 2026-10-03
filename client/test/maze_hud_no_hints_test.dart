import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/hud.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C4 — MazeHud's locked hint button: dimmed, outline icon, no
/// remaining-uses badge, and un-tappable, whenever the No-Hints
/// Challenge is active.
void main() {
  Future<void> pumpHud(WidgetTester tester, {bool hintsLocked = false, VoidCallback? onHint}) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MazeHud(
          levelName: 'Test Level',
          elapsed: Duration.zero,
          starsCollected: 0,
          hintsRemaining: 3,
          onBack: () {},
          onHint: onHint ?? () {},
          onPause: () {},
          hintsLocked: hintsLocked,
        ),
      ),
    ));
  }

  testWidgets('unlocked: shows the lit bulb and the remaining-uses badge', (tester) async {
    await pumpHud(tester);

    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('locked: shows the outline bulb with no badge', (tester) async {
    await pumpHud(tester, hintsLocked: true);

    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('locked: tapping the hint button does not call onHint', (tester) async {
    var tapped = false;
    await pumpHud(tester, hintsLocked: true, onHint: () => tapped = true);

    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded));
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('unlocked: tapping the hint button does call onHint', (tester) async {
    var tapped = false;
    await pumpHud(tester, onHint: () => tapped = true);

    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
