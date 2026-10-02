import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/painters/environment_painter.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// B2, end to end: the level screen renders its environment backdrop
/// without exceptions, and honors both the player's "reduce motion"
/// setting and the system accessibility flag.
void main() {
  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  Future<void> pumpLevel(
    WidgetTester tester, {
    required int levelId,
    bool reduceMotionSetting = false,
    bool systemReduceMotion = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: systemReduceMotion),
        child: MazeGameScreen(
          level: kMazeLevels.firstWhere((l) => l.id == levelId),
          isLastLevel: false,
          initialProgress: MazeProgress(reduceMotionEnabled: reduceMotionSetting),
          onLevelCompleted: (_, __, ___) {},
          onProgressChanged: (_) {},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  for (final levelId in [1, 5, 8, 9]) {
    testWidgets('level $levelId renders its environment backdrop without error', (tester) async {
      await pumpLevel(tester, levelId: levelId);

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EnvironmentPainter),
        findsOneWidget,
      );

      await unmount(tester);
    });
  }

  testWidgets('with the player setting on, ambient motion does not advance', (tester) async {
    await pumpLevel(tester, levelId: 1, reduceMotionSetting: true);

    final painterBefore = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    await tester.pump(const Duration(seconds: 2));

    final painterAfter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    expect(painterAfter.particles, painterBefore.particles);

    await unmount(tester);
  });

  testWidgets('with the system accessibility flag on, ambient motion does not advance',
      (tester) async {
    await pumpLevel(tester, levelId: 1, systemReduceMotion: true);

    final painterBefore = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    await tester.pump(const Duration(seconds: 2));

    final painterAfter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    expect(painterAfter.particles, painterBefore.particles);

    await unmount(tester);
  });

  testWidgets('with both settings off, ambient motion does advance', (tester) async {
    await pumpLevel(tester, levelId: 1);

    final painterBefore = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    await tester.pump(const Duration(seconds: 2));

    final painterAfter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EnvironmentPainter>()
        .single;

    expect(painterAfter.particles, isNot(painterBefore.particles));

    await unmount(tester);
  });
}
