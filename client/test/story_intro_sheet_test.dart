import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/ui/story_intro_sheet.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// B3 — the story intro sheet's typewriter reveal (skippable by tap),
/// reduce-motion behavior, and the optional narration button that only
/// shows once an asset probe says a clip exists.
void main() {
  Future<AppLocalizations> loadT() => AppLocalizations.delegate.load(const Locale('en'));

  Future<void> pumpSheet(
    WidgetTester tester, {
    bool systemReduceMotion = false,
    Future<bool> Function(String)? probeAssetExists,
  }) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: systemReduceMotion),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMazeStoryIntroSheet(
                context,
                kMazeLevels.first,
                probeAssetExists: probeAssetExists,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // the sheet's own slide-up animation
  }

  group('mazeNarrationAssetPath', () {
    test('builds the expected per-level, per-language path', () {
      expect(mazeNarrationAssetPath(5, 'ar'), 'sounds/maze/narration/level5_ar.mp3');
      expect(mazeNarrationAssetPath(1, 'en'), 'sounds/maze/narration/level1_en.mp3');
    });
  });

  group('typewriter reveal', () {
    testWidgets('the story starts partially revealed, not instantly complete', (tester) async {
      final t = await loadT();
      final fullStory = mazeLevelTextFor(t, 1).story;
      await pumpSheet(tester);

      // Already pumped 300ms above (out of ~2.4s max reveal duration), so
      // the full story should not be on screen yet.
      expect(find.text(fullStory), findsNothing);
    });

    testWidgets('tapping the story text jumps straight to the full text', (tester) async {
      final t = await loadT();
      final fullStory = mazeLevelTextFor(t, 1).story;
      await pumpSheet(tester);
      expect(find.text(fullStory), findsNothing);

      await tester.tap(find.byKey(const Key('mazeStorySkipArea')));
      await tester.pump();

      expect(find.text(fullStory), findsOneWidget);
    });

    testWidgets('given enough time, the story completes on its own without a tap', (tester) async {
      final t = await loadT();
      final fullStory = mazeLevelTextFor(t, 1).story;
      await pumpSheet(tester);

      await tester.pump(const Duration(seconds: 3)); // past the 2.4s cap

      expect(find.text(fullStory), findsOneWidget);
    });

    testWidgets('with the system reduce-motion flag on, the full story shows immediately',
        (tester) async {
      final t = await loadT();
      final fullStory = mazeLevelTextFor(t, 1).story;
      await pumpSheet(tester, systemReduceMotion: true);

      expect(find.text(fullStory), findsOneWidget);
    });
  });

  group('narration button', () {
    testWidgets('hidden when no narration asset exists for this level/language', (tester) async {
      final t = await loadT();
      await pumpSheet(tester, probeAssetExists: (_) async => false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel(t.mazeNarrationPlay), findsNothing);
    });

    testWidgets('shown once the probe resolves true', (tester) async {
      final t = await loadT();
      await pumpSheet(tester, probeAssetExists: (_) async => true);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel(t.mazeNarrationPlay), findsOneWidget);
    });

    testWidgets('probes with the path for this level and the active locale', (tester) async {
      String? probed;
      await pumpSheet(
        tester,
        probeAssetExists: (path) async {
          probed = path;
          return false;
        },
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(probed, mazeNarrationAssetPath(kMazeLevels.first.id, 'en'));
    });

    testWidgets('a slow probe never blocks the sheet from being usable meanwhile', (tester) async {
      await pumpSheet(
        tester,
        probeAssetExists: (_) => Future.delayed(const Duration(seconds: 2), () => true),
      );

      // The sheet (Start button etc.) is already interactive without
      // waiting for the probe to resolve.
      expect(find.text('Start'), findsOneWidget);

      // Let the probe actually resolve before the test ends, so no timer
      // outlives it.
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('tapping Start still resolves the sheet with true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showMazeStoryIntroSheet(context, kMazeLevels.first);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isTrue);
  });
}
