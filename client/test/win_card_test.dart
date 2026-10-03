import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/game_controller.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_generator.dart';
import 'package:islamic_game/features/seerah_maze/logic/maze_solver.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_level.dart';
import 'package:islamic_game/features/seerah_maze/ui/win_card.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// E1/E2 — the win card's confetti (only on a true 3-star clear) and its
/// "New Best Time!" highlight (driven by the caller's own isNewBestTime
/// flag, independent of the star rating).
void main() {
  const generator = MazeGenerator();
  const solver = MazeSolver();

  MazeLevel levelWith({required Duration starTimeThreshold}) => MazeLevel(
        id: 1,
        gridSize: 6,
        seed: 1,
        extraLoopCount: 0,
        starTimeThreshold: starTimeThreshold,
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      );

  /// Drives [controller] to collect every star and then reach the
  /// destination, via chained shortest paths (start -> star1 -> star2 ->
  /// ... -> destination) — a real 3-star clear regardless of how many
  /// dead-end stars this particular seed happened to generate.
  void winPerfectly(GameController controller, MazeGenerationResult maze) {
    var from = maze.start;
    final waypoints = [...maze.starCoords, maze.destination];
    for (final to in waypoints) {
      final path = solver.shortestPath(maze, from, to)!;
      for (var i = 1; i < path.length; i++) {
        final a = path[i - 1];
        final b = path[i];
        final direction = MazeDirection.values
            .firstWhere((d) => MazeCoord(a.row + d.deltaRow, a.col + d.deltaCol) == b);
        controller.move(direction);
      }
      from = to;
    }
  }

  Future<ConfettiController> pumpCard(
    WidgetTester tester, {
    required GameController controller,
    required MazeLevel level,
    bool isNewBestTime = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showMazeWinCard(
              context,
              level: level,
              controller: controller,
              isLastLevel: false,
              isNewBestTime: isNewBestTime,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950)); // past the stars reveal animation
    return tester.widget<ConfettiWidget>(find.byType(ConfettiWidget)).confettiController;
  }

  testWidgets('a true 3-star clear plays confetti', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    final level = levelWith(starTimeThreshold: const Duration(hours: 1));
    final controller = GameController(maze: maze, level: level);
    winPerfectly(controller, maze);
    expect(controller.rating, MazeRating.three);

    final confetti = await pumpCard(tester, controller: controller, level: level);

    expect(confetti.state, ConfettiControllerState.playing);
  });

  testWidgets('finishing over time (so under 3 stars) does not play confetti', (tester) async {
    final maze = generator.generate(size: 6, seed: 1);
    // A threshold of zero can never be met once any time has actually
    // elapsed, so this can be at best 2 stars even collecting everything.
    final level = levelWith(starTimeThreshold: Duration.zero);
    final controller = GameController(maze: maze, level: level);
    controller.tick(const Duration(seconds: 1));
    winPerfectly(controller, maze);
    expect(controller.rating, isNot(MazeRating.three));

    final confetti = await pumpCard(tester, controller: controller, level: level);

    expect(confetti.state, ConfettiControllerState.stopped);
  });

  testWidgets('isNewBestTime shows the New Best badge instead of the plain Time label',
      (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    final maze = generator.generate(size: 6, seed: 1);
    final level = levelWith(starTimeThreshold: const Duration(hours: 1));
    final controller = GameController(maze: maze, level: level);
    winPerfectly(controller, maze);

    await pumpCard(tester, controller: controller, level: level, isNewBestTime: true);

    expect(find.text(t.mazeNewBestTimeBadge), findsOneWidget);
    expect(find.text(t.mazeTimeStat), findsNothing);
  });

  testWidgets('without isNewBestTime the plain Time label shows as usual', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    final maze = generator.generate(size: 6, seed: 1);
    final level = levelWith(starTimeThreshold: const Duration(hours: 1));
    final controller = GameController(maze: maze, level: level);
    winPerfectly(controller, maze);

    await pumpCard(tester, controller: controller, level: level, isNewBestTime: false);

    expect(find.text(t.mazeTimeStat), findsOneWidget);
    expect(find.text(t.mazeNewBestTimeBadge), findsNothing);
  });
}
