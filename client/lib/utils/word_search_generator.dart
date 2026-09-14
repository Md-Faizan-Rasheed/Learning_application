import 'dart:math';

import 'hijri_months.dart';
import 'names_of_allah.dart';
import 'prophet_names.dart';
import 'word_bank_entry.dart';

enum WordSearchDifficulty { easy, medium, hard }

enum WordSearchCategory { prophets, namesOfAllah, hijriMonths }

/// The word bank backing each category — the one place a new category needs
/// to be registered once its data file exists.
const wordSearchCategoryWords = <WordSearchCategory, List<WordEntry>>{
  WordSearchCategory.prophets: kProphetNames,
  WordSearchCategory.namesOfAllah: kNamesOfAllah,
  WordSearchCategory.hijriMonths: kHijriMonths,
};

class WordSearchDifficultyConfig {
  const WordSearchDifficultyConfig(
      {required this.gridSize, required this.wordCount});

  final int gridSize;
  final int wordCount;
}

const wordSearchDifficultyConfigs =
    <WordSearchDifficulty, WordSearchDifficultyConfig>{
  WordSearchDifficulty.easy:
      WordSearchDifficultyConfig(gridSize: 8, wordCount: 6),
  WordSearchDifficulty.medium:
      WordSearchDifficultyConfig(gridSize: 11, wordCount: 8),
  WordSearchDifficulty.hard:
      WordSearchDifficultyConfig(gridSize: 14, wordCount: 10),
};

/// A single cell coordinate on the puzzle grid.
class GridPos {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// One word successfully placed on the grid, in placement order (start
/// cell to end cell) — a swipe can still match it read in either direction.
class PlacedWord {
  const PlacedWord(this.word, this.cells);

  final WordEntry word;
  final List<GridPos> cells;
}

class WordSearchPuzzle {
  const WordSearchPuzzle({
    required this.size,
    required this.grid,
    required this.placedWords,
  });

  final int size;
  final List<List<String>> grid;
  final List<PlacedWord> placedWords;
}

const _directions = <(int, int)>[
  (-1, 0), (1, 0), (0, -1), (0, 1), // vertical / horizontal
  (-1, -1), (-1, 1), (1, -1), (1, 1), // diagonals
];

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _maxAttemptsPerWord = 200;

/// Generates a word-search puzzle. Words that can't be placed after
/// [_maxAttemptsPerWord] tries are silently dropped rather than failing the
/// whole generation — the caller just gets a puzzle with a couple fewer
/// words than requested, which is a fine trade for robustness.
WordSearchPuzzle generateWordSearch({
  required List<WordEntry> words,
  required int size,
  Random? random,
}) {
  final rng = random ?? Random();
  final grid = List.generate(size, (_) => List<String?>.filled(size, null));
  final placed = <PlacedWord>[];

  final sorted = [...words]
    ..sort((a, b) => b.word.length.compareTo(a.word.length));

  for (final word in sorted) {
    final letters = word.word.split('');
    var placedOk = false;

    for (var attempt = 0;
        attempt < _maxAttemptsPerWord && !placedOk;
        attempt++) {
      final dir = _directions[rng.nextInt(_directions.length)];
      final dr = dir.$1;
      final dc = dir.$2;
      final startRow = rng.nextInt(size);
      final startCol = rng.nextInt(size);
      final endRow = startRow + dr * (letters.length - 1);
      final endCol = startCol + dc * (letters.length - 1);
      if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) {
        continue;
      }

      final cells = <GridPos>[];
      var fits = true;
      for (var i = 0; i < letters.length; i++) {
        final r = startRow + dr * i;
        final c = startCol + dc * i;
        final existing = grid[r][c];
        if (existing != null && existing != letters[i]) {
          fits = false;
          break;
        }
        cells.add(GridPos(r, c));
      }
      if (!fits) continue;

      for (var i = 0; i < letters.length; i++) {
        grid[cells[i].row][cells[i].col] = letters[i];
      }
      placed.add(PlacedWord(word, cells));
      placedOk = true;
    }
  }

  final filled = List.generate(
    size,
    (r) => List.generate(
      size,
      (c) => grid[r][c] ?? _alphabet[rng.nextInt(_alphabet.length)],
    ),
  );

  return WordSearchPuzzle(size: size, grid: filled, placedWords: placed);
}

/// Picks a subset of [category]'s word bank sized for [difficulty] and
/// generates a puzzle from it — the one entry point the screen actually
/// calls to start (or restart) a game.
///
/// [priority] (from WordMasteryStore) optionally biases which words get
/// picked: higher-weighted words (never seen, or previously hinted-on) come
/// up more often than already-mastered ones. Omitting it (the default)
/// keeps the original uniform-random behavior, so existing callers/tests
/// are unaffected.
WordSearchPuzzle generatePuzzleForDifficulty(
  WordSearchDifficulty difficulty, {
  WordSearchCategory category = WordSearchCategory.prophets,
  Map<String, int>? priority,
  Random? random,
}) {
  final rng = random ?? Random();
  final config = wordSearchDifficultyConfigs[difficulty]!;
  final bank = wordSearchCategoryWords[category]!;

  // Prefer words that can actually fit this grid size — a category like
  // Hijri Months mixes short and long transliterations, and a word longer
  // than the grid would just be silently dropped by generateWordSearch
  // anyway. Falling back to the full bank keeps this a no-op for banks
  // (like the prophets) where everything already fits every grid size.
  final fitting = bank.where((w) => w.word.length <= config.gridSize).toList();
  final pool = fitting.isEmpty ? [...bank] : fitting;

  final words = _selectWords(pool, config.wordCount, rng, priority);
  return generateWordSearch(words: words, size: config.gridSize, random: rng);
}

/// Picks [count] entries from [pool] without replacement. With no
/// [priority] map, this is a plain uniform shuffle-and-take. With one, it's
/// weighted sampling (the Efraimidis-Spirakis A-Res method: each candidate
/// gets a random key raised to 1/weight, and the top [count] keys win) —
/// higher weight skews a word's key closer to 1.0 more often, without ever
/// making a low-weight word impossible to draw.
List<WordEntry> _selectWords(
  List<WordEntry> pool,
  int count,
  Random rng,
  Map<String, int>? priority,
) {
  if (priority == null || priority.isEmpty) {
    return ([...pool]..shuffle(rng)).take(count).toList();
  }
  final keyed = pool.map((w) {
    final weight = max(1, priority[w.word] ?? 1);
    final key = pow(rng.nextDouble(), 1 / weight).toDouble();
    return (key, w);
  }).toList()
    ..sort((a, b) => b.$1.compareTo(a.$1));
  return keyed.take(count).map((e) => e.$2).toList();
}
