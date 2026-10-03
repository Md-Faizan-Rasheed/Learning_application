/// C3 — per-round difficulty for Endless mode. Rounds chain without ever
/// returning to a menu, so difficulty has to come from a pure function of
/// the round number rather than from a fixed level list: [gridSize] grows
/// every other round and [extraLoopCount] every third, both capped at the
/// same ceiling the hardest campaign level (10) already uses, so Endless
/// never gets harder than the campaign's own difficulty ever goes.
class EndlessRoundConfig {
  const EndlessRoundConfig({
    required this.gridSize,
    required this.extraLoopCount,
    required this.timeBonus,
  });

  final int gridSize;
  final int extraLoopCount;

  /// Added to the time bank when this round is solved — shrinks slowly as
  /// rounds climb (floored, never zero) so a long run demands increasingly
  /// efficient solving rather than stopping dead.
  final Duration timeBonus;
}

/// How long the bank starts with, before any round has been solved.
const Duration endlessStartingBank = Duration(seconds: 60);

EndlessRoundConfig endlessConfigForRound(int round) {
  assert(round >= 1, 'rounds are 1-based');
  final gridSize = (6 + (round - 1) ~/ 2).clamp(6, 16);
  final extraLoopCount = ((round - 1) ~/ 3).clamp(0, 5);
  final bonusSeconds = (50 - round).clamp(20, 50);
  return EndlessRoundConfig(
    gridSize: gridSize,
    extraLoopCount: extraLoopCount,
    timeBonus: Duration(seconds: bonusSeconds),
  );
}
