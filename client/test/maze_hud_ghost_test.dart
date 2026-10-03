import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/hud.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C1 — MazeHud's ghost delta pill: hidden with nothing to compare,
/// otherwise reading "-X.Xs" when ahead or "+X.Xs" when behind.
void main() {
  Future<void> pumpHud(WidgetTester tester, {double? ghostDeltaSeconds}) {
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
          ghostDeltaSeconds: ghostDeltaSeconds,
        ),
      ),
    ));
  }

  testWidgets('shows nothing when there is no ghost delta', (tester) async {
    await pumpHud(tester);

    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('shows a negative "ahead" reading when the delta is negative', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpHud(tester, ghostDeltaSeconds: -1.2);

    expect(find.text(t.mazeGhostDeltaAhead('1.2')), findsOneWidget);
  });

  testWidgets('shows a positive "behind" reading when the delta is positive', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpHud(tester, ghostDeltaSeconds: 0.8);

    expect(find.text(t.mazeGhostDeltaBehind('0.8')), findsOneWidget);
  });

  testWidgets('a delta of exactly zero reads as "ahead" (ties go to the player)', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpHud(tester, ghostDeltaSeconds: 0.0);

    expect(find.text(t.mazeGhostDeltaAhead('0.0')), findsOneWidget);
  });

  testWidgets('works in the vertical side-panel layout too', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
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
            ghostDeltaSeconds: -2.0,
          ),
        ),
      ),
    ));

    expect(find.text(t.mazeGhostDeltaAhead('2.0')), findsOneWidget);
  });
}
