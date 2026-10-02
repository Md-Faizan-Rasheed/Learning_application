import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';
import 'package:islamic_game/features/seerah_maze/ui/mechanic_tooltip_banner.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<MazeMechanicTooltip> queue, VoidCallback onDone) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MazeMechanicTooltipBanner(queue: queue, onDismissedAll: onDone),
      ),
    ));
  }

  testWidgets('an empty queue renders nothing', (tester) async {
    var called = false;
    await pump(tester, const [], () => called = true);

    expect(find.byType(GestureDetector), findsNothing);
    expect(called, isFalse);
  });

  testWidgets('shows the first tooltip in the queue', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pump(tester, [MazeMechanicTooltip.cave, MazeMechanicTooltip.doors], () {});
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text(t.mazeTooltipCave), findsOneWidget);
    expect(find.text(t.mazeTooltipDoors), findsNothing);
  });

  testWidgets('tapping advances to the next tooltip in the queue', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pump(tester, [MazeMechanicTooltip.cave, MazeMechanicTooltip.doors], () {});
    await tester.pump(const Duration(milliseconds: 260));

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text(t.mazeTooltipCave), findsNothing);
    expect(find.text(t.mazeTooltipDoors), findsOneWidget);
  });

  testWidgets('tapping the last tooltip calls onDismissedAll instead of advancing', (tester) async {
    var called = false;
    await pump(tester, [MazeMechanicTooltip.cave], () => called = true);
    await tester.pump(const Duration(milliseconds: 260));

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('a single-item queue never calls onDismissedAll before it is tapped', (tester) async {
    var called = false;
    await pump(tester, [MazeMechanicTooltip.sand], () => called = true);
    await tester.pump(const Duration(milliseconds: 260));

    expect(called, isFalse);
  });

  testWidgets('announces the tooltip text as a live region for screen readers', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pump(tester, [MazeMechanicTooltip.teleport], () {});
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.bySemanticsLabel(t.mazeTooltipTeleport), findsOneWidget);
  });
}
