import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_progress_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_character_skin.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/achievements_screen.dart';
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

  testWidgets('the achievements button navigates to MazeAchievementsScreen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.emoji_events_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MazeAchievementsScreen), findsOneWidget);
  });

  testWidgets('a fresh install shows Explorer Level 1 in the header pill', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(tester);

    expect(find.text(t.mazeExplorerLevelLabel(1)), findsOneWidget);
  });

  testWidgets('earned stars raise the Explorer Level shown in the header pill', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await const MazeProgressRepository().save(
      const MazeProgress(starsByLevel: {1: 3, 2: 3, 3: 3}),
    );

    await pumpScreen(tester);

    // 9 stars * 10 = 90, plus firstSteps unlocked (+50) = 140 XP -> level 2
    // (past level 2's 50-XP threshold, short of level 3's 200).
    expect(find.text(t.mazeExplorerLevelLabel(2)), findsOneWidget);
  });

  testWidgets('tapping the level pill navigates to MazeAchievementsScreen', (tester) async {
    await pumpScreen(tester);

    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(t.mazeExplorerLevelLabel(1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MazeAchievementsScreen), findsOneWidget);
  });

  testWidgets('the customize button opens the skin sheet and a choice persists', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await const MazeProgressRepository().save(
      MazeProgress(
        // A fully-completed campaign comfortably clears Explorer Level 5
        // (Ink's unlock level) — see explorer_level_test.dart for the XP
        // formula this relies on.
        starsByLevel: {for (var i = 1; i <= kMazeLevels.length; i++) i: 3},
        collectedFactLevelIds: {for (var i = 1; i <= kMazeLevels.length; i++) i},
        noHintsClearedLevelIds: {for (var i = 1; i <= kMazeLevels.length; i++) i},
      ),
    );
    await pumpScreen(tester);

    // Not pumpAndSettle: the journey map underneath keeps its own
    // repeating pulse/traveling-dot animations going even with the sheet
    // open, so pumpAndSettle would never see "no more frames scheduled".
    await tester.tap(find.byIcon(Icons.palette_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.mazeCustomizeScreenTitle), findsOneWidget);

    await tester.tap(find.text(t.mazeSkinInkName));
    await tester.pump();
    await tester.tap(find.text(t.mazeLibraryCloseButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await const MazeProgressRepository().load();
    expect(saved.selectedSkin, MazeCharacterSkinId.ink);
  });
}
