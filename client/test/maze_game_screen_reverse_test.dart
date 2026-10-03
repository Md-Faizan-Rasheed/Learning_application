import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_board.dart';
import 'package:islamic_game/features/seerah_maze/ui/maze_game_screen.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C5, end to end through the real MazeGameScreen: the reverse-controls
/// toggle is actually threaded down onto the real board, and the HUD
/// shows its reminder pill while it's on. The direction-inversion
/// mechanics themselves (which cell a keypress actually lands on) are
/// covered precisely in maze_board_reverse_test.dart; this file only
/// checks that MazeGameScreen wires the setting through correctly —
/// same split as maze_game_screen_ghost_test.dart's own
/// `board.ghostPlayer` checks.
void main() {
  final level = kMazeLevels.first;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('shows the reverse-controls reminder pill when the toggle is on', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(reverseControlsEnabled: true),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(t.mazeReverseActiveLabel), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('does not show the pill when the toggle is off', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(t.mazeReverseActiveLabel), findsNothing);

    await unmount(tester);
  });

  testWidgets('MazeBoardWidget receives reverseControlsEnabled: true from the progress toggle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(reverseControlsEnabled: true),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final board = tester.widget<MazeBoardWidget>(find.byType(MazeBoardWidget));
    expect(board.reverseControlsEnabled, isTrue);

    await unmount(tester);
  });

  testWidgets('MazeBoardWidget receives reverseControlsEnabled: false by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MazeGameScreen(
        level: level,
        isLastLevel: false,
        initialProgress: const MazeProgress(),
        onLevelCompleted: (_, __, ___) {},
        onProgressChanged: (_) {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final board = tester.widget<MazeBoardWidget>(find.byType(MazeBoardWidget));
    expect(board.reverseControlsEnabled, isFalse);

    await unmount(tester);
  });
}
