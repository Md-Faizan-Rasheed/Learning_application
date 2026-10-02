import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';
import 'package:islamic_game/features/seerah_maze/painters/fog_painter.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_board.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// A1 — the fog layer is only built when this level/setting combination
/// actually has fog, so a non-fog level keeps Phase 1's exact layer stack
/// and pays nothing for the mechanic.
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel level({MazeMechanics mechanics = MazeMechanics.none}) => MazeLevel(
        id: 1,
        gridSize: 6,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: const Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
        mechanics: mechanics,
      );

  Future<void> pumpBoard(
    WidgetTester tester, {
    required MazeLevel forLevel,
    bool fogEnabled = false,
  }) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: forLevel);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 360,
          child: MazeBoardWidget(
            controller: controller,
            solver: solver,
            fogEnabled: fogEnabled,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('no fog layer on a plain level with the setting off', (tester) async {
    await pumpBoard(tester, forLevel: level());

    expect(find.byType(FogPainter), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FogPainter),
      findsNothing,
    );
  });

  testWidgets('the player setting alone turns fog on (Phase 1 behavior)', (tester) async {
    await pumpBoard(tester, forLevel: level(), fogEnabled: true);

    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FogPainter),
      findsOneWidget,
    );
  });

  testWidgets('a level that opts into fog gets it even with the setting off', (tester) async {
    await pumpBoard(
      tester,
      forLevel: level(mechanics: const MazeMechanics(fog: FogConfig(visibilityRadius: 2))),
    );

    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FogPainter),
      findsOneWidget,
    );
  });

  testWidgets('the fog board announces fog mode to screen readers', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpBoard(tester, forLevel: level(), fogEnabled: true);

    expect(find.bySemanticsLabel(t.mazeBoardSemanticsFog), findsOneWidget);
    expect(find.bySemanticsLabel(t.mazeBoardSemantics), findsNothing);
  });

  testWidgets('a non-fog board keeps the plain board announcement', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpBoard(tester, forLevel: level());

    expect(find.bySemanticsLabel(t.mazeBoardSemantics), findsOneWidget);
  });

  // A2 — a cave level is fog with a lantern-driven radius, so it builds the
  // same layer without needing the player's fog setting at all.
  testWidgets('a cave level builds the fog layer with a destination glow', (tester) async {
    await pumpBoard(
      tester,
      forLevel: level(mechanics: const MazeMechanics(cave: CaveConfig())),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FogPainter>()
        .single;

    expect(painter.destinationGlow, isNotNull);
    expect(painter.hiddenVeil, greaterThan(0.95), reason: 'a cave is near-black');
  });

  testWidgets('an ordinary fog level has no destination glow', (tester) async {
    await pumpBoard(tester, forLevel: level(), fogEnabled: true);

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FogPainter>()
        .single;

    expect(painter.destinationGlow, isNull);
  });

  testWidgets('a cave level keeps running after a background/resume cycle', (tester) async {
    await pumpBoard(
      tester,
      forLevel: level(mechanics: const MazeMechanics(cave: CaveConfig())),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FogPainter),
      findsOneWidget,
    );
  });
}
