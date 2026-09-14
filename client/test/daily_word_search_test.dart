import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/daily_word_search.dart';
import 'package:islamic_game/utils/word_search_generator.dart';

void main() {
  group('Daily Challenge determinism', () {
    test('the same date always produces the identical puzzle', () {
      final date = DateTime(2026, 9, 14);

      final a = generateDailyChallengePuzzle(date);
      final b = generateDailyChallengePuzzle(date);

      expect(dailyChallengeCategory(date), dailyChallengeCategory(date));
      expect(a.grid, equals(b.grid));
      expect(
        a.placedWords.map((p) => p.word.word).toList(),
        equals(b.placedWords.map((p) => p.word.word).toList()),
      );
    });

    test('different dates usually produce different puzzles', () {
      final a = generateDailyChallengePuzzle(DateTime(2026, 9, 14));
      final b = generateDailyChallengePuzzle(DateTime(2026, 9, 15));

      final sameWords = a.placedWords.map((p) => p.word.word).toSet();
      final otherWords = b.placedWords.map((p) => p.word.word).toSet();
      expect(sameWords, isNot(equals(otherWords)));
    });

    test('the fixed difficulty always yields a non-empty puzzle', () {
      final puzzle = generateDailyChallengePuzzle(DateTime(2026, 12, 25));
      expect(puzzle.placedWords, isNotEmpty);
      expect(puzzle.size, wordSearchDifficultyConfigs[kDailyChallengeDifficulty]!.gridSize);
    });

    test('dailyChallengeDateString formats with zero-padding', () {
      expect(dailyChallengeDateString(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
