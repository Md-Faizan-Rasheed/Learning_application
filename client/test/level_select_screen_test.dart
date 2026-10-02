import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/ui/level_select_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B1 — the level select screen now renders the levels as a winding
/// journey map (circular nodes + a curved path) rather than a plain list,
/// but it owns exactly the same progress/unlock/navigation logic as
/// before, so these tests assert that logic through the new node shape:
/// Semantics labels (unlocked/locked), tap-to-open, and the header's star
/// total.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SeerahMazeLevelSelectScreen(),
      ),
    );
    await tester.pump();
    // Lets the initial SharedPreferences-backed progress load resolve
    // (an async gap, not an animation), then the auto-center-on-current
    // scroll animation (500ms) finish, before any assertion runs.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
  }

  String unlockedLabel(WidgetTester tester, int levelId, {int stars = 0}) {
    final t = AppLocalizations.of(tester.element(find.byType(SeerahMazeLevelSelectScreen)))!;
    final levelText = mazeLevelTextFor(t, levelId);
    return t.mazeLevelSemanticsUnlocked(levelId, levelText.character, levelText.destination) +
        (stars > 0 ? t.mazeStarsEarnedSuffix(stars) : '');
  }

  String lockedLabel(WidgetTester tester, int levelId) {
    final t = AppLocalizations.of(tester.element(find.byType(SeerahMazeLevelSelectScreen)))!;
    return t.mazeLevelSemanticsLocked(levelId);
  }

  testWidgets('on a fresh install, only level 1 is unlocked', (tester) async {
    await pumpScreen(tester);

    expect(find.bySemanticsLabel(unlockedLabel(tester, 1)), findsOneWidget);
    expect(find.bySemanticsLabel(lockedLabel(tester, 2)), findsOneWidget);

    // Scroll to the very last level and confirm it's locked too.
    final lastLevel = kMazeLevels.last;
    final lastLevelNode = find.bySemanticsLabel(lockedLabel(tester, lastLevel.id));
    await tester.scrollUntilVisible(lastLevelNode, 400, scrollable: find.byType(Scrollable));
    await tester.pump();
    expect(lastLevelNode, findsOneWidget);
  });

  testWidgets('tapping a locked level shows a message and does not navigate', (tester) async {
    await pumpScreen(tester);

    final level2 = find.bySemanticsLabel(lockedLabel(tester, 2));
    expect(level2, findsOneWidget);
    await tester.tap(level2);
    await tester.pump();

    expect(find.text('Finish the previous level to unlock this one.'), findsOneWidget);
    // Still on the level select screen, not pushed into the story intro.
    expect(find.text('Seerah Maze'), findsOneWidget);
  });

  testWidgets('tapping the unlocked first level opens its story intro sheet', (tester) async {
    await pumpScreen(tester);

    final level1 = find.bySemanticsLabel(unlockedLabel(tester, 1));
    expect(level1, findsOneWidget);
    await tester.tap(level1);
    // Not pumpAndSettle(): the journey map behind the sheet keeps repeating
    // pulse/dot animations running, which never "settle".
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Start', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the header shows total stars collected out of the maximum possible', (tester) async {
    await pumpScreen(tester);
    expect(find.text('0/${kMazeLevels.length * 3}'), findsOneWidget);
  });

  testWidgets('every level 1-10 renders exactly one node, locked or unlocked', (tester) async {
    await pumpScreen(tester);

    // Level 1 is unlocked; levels 2-10 are locked on a fresh install —
    // confirms the full set renders (via scrolling), not just the ones
    // near the top of the viewport.
    expect(find.bySemanticsLabel(unlockedLabel(tester, 1)), findsOneWidget);
    for (final level in kMazeLevels.skip(1)) {
      final node = find.bySemanticsLabel(lockedLabel(tester, level.id));
      await tester.scrollUntilVisible(node, 400, scrollable: find.byType(Scrollable));
      await tester.pump();
      expect(node, findsOneWidget, reason: 'level ${level.id}');
    }
  });
}
