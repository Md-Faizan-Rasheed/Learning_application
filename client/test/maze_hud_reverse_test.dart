import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/hud.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C5 — MazeHud's reverse-controls reminder pill: hidden unless active.
void main() {
  Future<void> pumpHud(WidgetTester tester, {bool reverseControlsActive = false}) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MazeHud(
          levelName: 'Test Level',
          elapsed: Duration.zero,
          starsCollected: 0,
          onBack: () {},
          onHint: () {},
          onPause: () {},
          reverseControlsActive: reverseControlsActive,
        ),
      ),
    ));
  }

  testWidgets('hidden when reverse controls are off', (tester) async {
    await pumpHud(tester);

    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });

  testWidgets('shown when reverse controls are on', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpHud(tester, reverseControlsActive: true);

    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.text(t.mazeReverseActiveLabel), findsOneWidget);
  });

  testWidgets('works in the vertical side-panel layout too', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 104,
          child: MazeHud(
            levelName: 'Test Level',
            elapsed: Duration.zero,
            starsCollected: 0,
            axis: Axis.vertical,
            onBack: () {},
            onHint: () {},
            onPause: () {},
            reverseControlsActive: true,
          ),
        ),
      ),
    ));

    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });
}
