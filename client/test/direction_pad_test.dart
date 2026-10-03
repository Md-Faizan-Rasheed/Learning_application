import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/constants/maze_constants.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_direction.dart';
import 'package:islamic_game/features/seerah_maze/ui/direction_pad.dart';
import 'package:islamic_game/l10n/app_localizations.dart';

/// C6 — the on-screen D-pad: a plain tap fires once, holding repeats on
/// MazeConstants.keyRepeatInterval, and releasing stops the repeat.
void main() {
  Future<void> pumpPad(WidgetTester tester, List<MazeDirection> taps) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MazeDirectionPad(onDirection: taps.add),
      ),
    ));
  }

  testWidgets('a plain tap on the up button fires north exactly once', (tester) async {
    final taps = <MazeDirection>[];
    await pumpPad(tester, taps);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();

    expect(taps, [MazeDirection.north]);
  });

  testWidgets('each arrow fires its own direction', (tester) async {
    final taps = <MazeDirection>[];
    await pumpPad(tester, taps);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_left_rounded));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
    await tester.pump();

    expect(taps, [MazeDirection.south, MazeDirection.west, MazeDirection.east]);
  });

  testWidgets('holding the button repeats on the key-repeat interval', (tester) async {
    final taps = <MazeDirection>[];
    await pumpPad(tester, taps);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.keyboard_arrow_up_rounded)),
    );
    expect(taps, [MazeDirection.north]);

    await tester.pump(MazeConstants.keyRepeatInterval);
    expect(taps, [MazeDirection.north, MazeDirection.north]);

    await tester.pump(MazeConstants.keyRepeatInterval);
    expect(taps.length, 3);

    await gesture.up();
    await tester.pump(MazeConstants.keyRepeatInterval * 3);
    expect(taps.length, 3, reason: 'releasing must stop the repeat timer');
  });

  testWidgets('a tap-cancel also stops the repeat timer', (tester) async {
    final taps = <MazeDirection>[];
    await pumpPad(tester, taps);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.keyboard_arrow_down_rounded)),
    );
    expect(taps, [MazeDirection.south]);

    // Dragging away triggers onTapCancel instead of onTapUp.
    await gesture.moveBy(const Offset(500, 500));
    await gesture.up();
    await tester.pump(MazeConstants.keyRepeatInterval * 3);

    expect(taps.length, 1);
  });
}
