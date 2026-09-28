import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/screens/multiplayer_screen.dart';

/// MultiplayerScreen owns a concrete MatchSocket field directly (no
/// injection seam), and its initState() immediately opens a real
/// socket_io_client connection to kApiBaseUrl — in a `flutter test` run
/// that's a real network attempt against the actual backend host, with no
/// way to fake-advance past it. Mounting this widget via pumpWidget/pump
/// therefore leaves a real pending connection timer at test teardown and
/// crashes the test binding's own invariant check, regardless of
/// campaignStageId — that's a pre-existing testability gap in this screen,
/// not something introduced by campaign mode.
///
/// So this test stays below the mount boundary: it constructs the widget
/// config directly (which only assigns fields — createState()/initState()
/// don't run until something actually pumps it into a tree) and checks the
/// one thing that determines the ordinary-match behavior this task must
/// preserve — that every existing call site (which never passes
/// campaignStageId) gets exactly the same null it always implicitly had.
void main() {
  test('campaignStageId defaults to null for every existing call site', () {
    const screen = MultiplayerScreen(lang: 'en', name: 'PytestPlayer');
    expect(screen.campaignStageId, isNull);
  });

  test('campaignStageId carries through when a caller does pass it', () {
    const screen = MultiplayerScreen(
      lang: 'en',
      name: 'PytestPlayer',
      campaignStageId: 'tazkiyah',
    );
    expect(screen.campaignStageId, 'tazkiyah');
  });
}
