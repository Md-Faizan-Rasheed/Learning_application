import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:islamic_game/features/seerah_maze/ui/mechanic_tooltip_banner.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// A8, end to end: MazeGameScreen actually shows the right tooltip queue
/// for a level, and a replay (with that mechanic already marked seen)
/// shows nothing.
void main() {
  late String caravanTooltipText;

  setUpAll(() async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    caravanTooltipText = t.mazeTooltipCaravan;
  });

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('level 4 (first caravan level) shows the caravan tooltip on a fresh save',
      (tester) async {
    MazeProgress? latest;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: kMazeLevels.firstWhere((l) => l.id == 4),
        isLastLevel: false,
        initialProgress: const MazeProgress(),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (p) => latest = p,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(MazeMechanicTooltipBanner), findsOneWidget);
    // Marked seen immediately, not deferred to dismissal.
    expect(latest, isNotNull);
    expect(latest!.seenMechanicTooltips, contains(MazeMechanicTooltip.caravan));

    await unmount(tester);
  });

  testWidgets('replaying level 4 with the tooltip already seen shows nothing', (tester) async {
    MazeProgress? latest;
    final progress = const MazeProgress().copyWith(
      seenMechanicTooltips: {MazeMechanicTooltip.caravan},
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: kMazeLevels.firstWhere((l) => l.id == 4),
        isLastLevel: false,
        initialProgress: progress,
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (p) => latest = p,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(caravanTooltipText), findsNothing);
    // Nothing new to persist, so the callback should never fire.
    expect(latest, isNull);

    await unmount(tester);
  });

  testWidgets('level 1 (no mechanics) never shows the banner', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: kMazeLevels.first,
        isLastLevel: false,
        initialProgress: const MazeProgress(),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(MazeMechanicTooltipBanner), findsNothing);

    await unmount(tester);
  });
}
