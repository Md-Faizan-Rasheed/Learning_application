import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_character_skin.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_progress.dart';
import 'package:islamic_game/features/seerah_maze/ui/customize_sheet.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// D3 — the Customize sheet: locked skins can't be selected, unlocked
/// ones can, and the sheet resolves with the chosen skin.
void main() {
  Future<void> pumpAndOpenSheet(
    WidgetTester tester, {
    required MazeProgress progress,
    required int explorerLevel,
    required ValueChanged<MazeProgress> onResolved,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await showMazeCustomizeSheet(
                context,
                progress: progress,
                explorerLevel: explorerLevel,
              );
              onResolved(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every skin name and locks ones above the current level', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpAndOpenSheet(
      tester,
      progress: const MazeProgress(),
      explorerLevel: 1,
      onResolved: (_) {},
    );

    expect(find.text(t.mazeSkinTravelerName), findsOneWidget);
    expect(find.text(t.mazeSkinGoldenName), findsOneWidget);
    expect(find.text(t.mazeSkinLockedAtLevel(3)), findsOneWidget);
    expect(find.text(t.mazeSkinLockedAtLevel(5)), findsOneWidget);
    expect(find.text(t.mazeSkinLockedAtLevel(7)), findsOneWidget);
  });

  testWidgets('tapping a locked skin does nothing', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpAndOpenSheet(
      tester,
      progress: const MazeProgress(),
      explorerLevel: 1,
      onResolved: (_) {},
    );

    // Traveler (the default) is unlocked and already selected, so one
    // checkmark legitimately exists before any tap.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text(t.mazeSkinGoldenName));
    await tester.pump();

    // Tapping the locked Golden skin must not move the checkmark onto it.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('selecting an unlocked skin and closing returns the updated progress',
      (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    MazeProgress? result;
    await pumpAndOpenSheet(
      tester,
      progress: const MazeProgress(),
      explorerLevel: 5, // unlocks traveler, golden and ink
      onResolved: (r) => result = r,
    );

    await tester.tap(find.text(t.mazeSkinInkName));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text(t.mazeLibraryCloseButton));
    await tester.pumpAndSettle();

    expect(result!.selectedSkin, MazeCharacterSkinId.ink);
  });

  testWidgets('closing without changing anything returns the skin unchanged', (tester) async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    MazeProgress? result;
    await pumpAndOpenSheet(
      tester,
      progress: const MazeProgress(selectedSkin: MazeCharacterSkinId.golden),
      explorerLevel: 5,
      onResolved: (r) => result = r,
    );

    await tester.tap(find.text(t.mazeLibraryCloseButton));
    await tester.pumpAndSettle();

    expect(result!.selectedSkin, MazeCharacterSkinId.golden);
  });
}
