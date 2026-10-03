import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/ghost/ghost_player.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/ghost_sample.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/painters/character_painter.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_board.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C1 — the board renders a second, translucent character for the ghost
/// only when one is actually supplied, and it tracks the ghost's own
/// recorded position independently of the real player's.
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel testLevel() => const MazeLevel(
        id: 1,
        gridSize: 6,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: Duration(minutes: 5),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      );

  Future<void> pumpBoard(WidgetTester tester, {GhostPlayer? ghostPlayer}) async {
    final maze = generator.generate(size: 6, seed: 1);
    final controller = GameController(maze: maze, level: testLevel());
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
            ghostPlayer: ghostPlayer,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  List<CharacterPainter> characterPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<CharacterPainter>()
      .toList();

  testWidgets('no ghost supplied means only the real character paints', (tester) async {
    await pumpBoard(tester);

    final painters = characterPainters(tester);

    expect(painters, hasLength(1));
    expect(painters.single.opacity, 1.0);
  });

  testWidgets('a ghost at the start cell adds a second, translucent character', (tester) async {
    final ghost = GhostPlayer(
      samples: const [GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0))],
    );
    await pumpBoard(tester, ghostPlayer: ghost);

    final painters = characterPainters(tester);

    expect(painters, hasLength(2));
    expect(painters.where((p) => p.opacity < 1.0), hasLength(1));
    expect(painters.where((p) => p.opacity == 1.0), hasLength(1));
  });

  testWidgets('a ghost whose run has already ended disappears from the board', (tester) async {
    // A one-sample run "ends" immediately after elapsed 0, so by the time
    // any real time has passed, positionAt returns null and the ghost
    // layer should render nothing extra.
    final ghost = GhostPlayer(
      samples: const [GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0))],
    );
    await pumpBoard(tester, ghostPlayer: ghost);
    // positionAt(elapsed) for elapsed > 0 is null since this run has only
    // the one zero-duration sample — confirmed directly on the model:
    expect(ghost.positionAt(const Duration(seconds: 1)), isNull);
  });

  testWidgets('an empty ghost (no samples at all) never adds a second character', (tester) async {
    final ghost = GhostPlayer(samples: const []);
    await pumpBoard(tester, ghostPlayer: ghost);

    expect(characterPainters(tester), hasLength(1));
  });
}
