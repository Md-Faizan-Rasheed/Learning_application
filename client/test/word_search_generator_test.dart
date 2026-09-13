import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/prophet_names.dart';
import 'package:islamic_game/utils/word_bank_entry.dart';
import 'package:islamic_game/utils/word_search_generator.dart';

String _readWord(WordSearchPuzzle puzzle, PlacedWord placed) {
  return placed.cells.map((pos) => puzzle.grid[pos.row][pos.col]).join();
}

void main() {
  group('generateWordSearch', () {
    test('every placed word reads correctly off its recorded cell path', () {
      final puzzle = generateWordSearch(
        words: kProphetNames,
        size: 14,
        random: Random(42),
      );

      expect(puzzle.placedWords, isNotEmpty);
      for (final placed in puzzle.placedWords) {
        expect(_readWord(puzzle, placed), placed.word.word);
      }
    });

    test('grid is fully filled with single uppercase letters', () {
      final puzzle = generateWordSearch(
        words: kProphetNames,
        size: 11,
        random: Random(7),
      );

      for (final row in puzzle.grid) {
        for (final cell in row) {
          expect(cell.length, 1);
          expect(cell, cell.toUpperCase());
          expect(RegExp(r'^[A-Z]$').hasMatch(cell), isTrue);
        }
      }
    });

    test('drops words that cannot possibly fit instead of crashing', () {
      // MUHAMMAD is 8 letters — cannot fit anywhere on a 4x4 grid.
      final puzzle = generateWordSearch(
        words: const [WordEntry('MUHAMMAD', 'Muhammad', 'test fact')],
        size: 4,
        random: Random(1),
      );

      expect(puzzle.placedWords, isEmpty);
      expect(puzzle.grid.length, 4);
      expect(puzzle.grid[0].length, 4);
    });

    test('placed word cell paths stay within grid bounds with no duplicates',
        () {
      final puzzle = generateWordSearch(
        words: kProphetNames,
        size: 8,
        random: Random(99),
      );

      for (final placed in puzzle.placedWords) {
        final cellSet = placed.cells.toSet();
        expect(cellSet.length, placed.cells.length);
        for (final pos in placed.cells) {
          expect(pos.row, inInclusiveRange(0, puzzle.size - 1));
          expect(pos.col, inInclusiveRange(0, puzzle.size - 1));
        }
      }
    });
  });
}
