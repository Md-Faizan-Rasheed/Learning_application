import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/endless/endless_round_config.dart';

void main() {
  test('round 1 starts at the easiest campaign-equivalent difficulty', () {
    final config = endlessConfigForRound(1);
    expect(config.gridSize, 6);
    expect(config.extraLoopCount, 0);
  });

  test('grid size grows every other round, capped at 16', () {
    expect(endlessConfigForRound(1).gridSize, 6);
    expect(endlessConfigForRound(3).gridSize, 7);
    expect(endlessConfigForRound(5).gridSize, 8);
    expect(endlessConfigForRound(100).gridSize, 16);
  });

  test('extra loop count grows every third round, capped at 5', () {
    expect(endlessConfigForRound(1).extraLoopCount, 0);
    expect(endlessConfigForRound(4).extraLoopCount, 1);
    expect(endlessConfigForRound(7).extraLoopCount, 2);
    expect(endlessConfigForRound(100).extraLoopCount, 5);
  });

  test('time bonus shrinks as rounds climb but never drops below the floor', () {
    expect(endlessConfigForRound(1).timeBonus, const Duration(seconds: 49));
    expect(endlessConfigForRound(30).timeBonus, const Duration(seconds: 20));
    expect(endlessConfigForRound(1000).timeBonus, const Duration(seconds: 20));
  });

  test('difficulty never decreases as rounds increase', () {
    var previousGrid = 0;
    var previousLoops = -1;
    for (var round = 1; round <= 50; round++) {
      final config = endlessConfigForRound(round);
      expect(config.gridSize, greaterThanOrEqualTo(previousGrid));
      expect(config.extraLoopCount, greaterThanOrEqualTo(previousLoops));
      previousGrid = config.gridSize;
      previousLoops = config.extraLoopCount;
    }
  });
}
