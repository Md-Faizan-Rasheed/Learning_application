import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/hud.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// Covers Phase 2 Milestone 1's "move the HUD into a side panel in
/// landscape/expanded, keep it a top bar in portrait/compact" requirement,
/// at a sample of the sizes the spec calls out by name.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size logicalSize) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    // One real frame so the board's own build-in/drop animations settle
    // enough to read a stable layout, without using pumpAndSettle (the
    // screen's 200ms game-tick Timer.periodic never naturally settles).
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// MazeGameScreen owns a periodic Timer for its elapsed-time tick, which
  /// survives past a bare pump; unmounting it runs dispose() and cancels
  /// that timer so the test doesn't fail on a pending-timer check.
  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('a compact portrait phone (360x640) keeps the HUD as a top bar', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(tester.widget<MazeHud>(find.byType(MazeHud)).axis, Axis.horizontal);

    await unmount(tester);
  });

  testWidgets('a portrait tablet (768x1024) still keeps the HUD as a top bar', (tester) async {
    await pumpAt(tester, const Size(768, 1024));

    expect(tester.takeException(), isNull);
    expect(tester.widget<MazeHud>(find.byType(MazeHud)).axis, Axis.horizontal);

    await unmount(tester);
  });

  testWidgets('a landscape tablet (1024x768) moves the HUD into a side panel', (tester) async {
    await pumpAt(tester, const Size(1024, 768));

    expect(tester.takeException(), isNull);
    expect(tester.widget<MazeHud>(find.byType(MazeHud)).axis, Axis.vertical);

    await unmount(tester);
  });

  testWidgets('a wide desktop window (1920x1080) keeps the HUD as a side panel', (tester) async {
    await pumpAt(tester, const Size(1920, 1080));

    expect(tester.takeException(), isNull);
    expect(tester.widget<MazeHud>(find.byType(MazeHud)).axis, Axis.vertical);

    await unmount(tester);
  });

  testWidgets('a medium-width landscape window (800x600) also gets the side panel', (tester) async {
    await pumpAt(tester, const Size(800, 600));

    expect(tester.takeException(), isNull);
    expect(tester.widget<MazeHud>(find.byType(MazeHud)).axis, Axis.vertical);

    await unmount(tester);
  });
}
