import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/word_search_generator.dart';

const _kMinCell = 28.0;
const _kMaxCell = 52.0;

/// The 8 straight directions a selection can snap to, indexed by "octant"
/// (nearest 45° increment of the drag angle from the start cell).
const _octantDirections = <(int, int)>[
  (0, 1),
  (1, 1),
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, -1),
  (-1, 0),
  (-1, 1),
];

/// Interactive letter grid: drag from one cell in a straight line to select
/// a run of letters, released to check it against the puzzle's still-unfound
/// words. Presentation + gesture only — all game state (score, timer, which
/// words are found) is owned by the screen that embeds this.
class WordSearchGrid extends StatefulWidget {
  const WordSearchGrid({
    super.key,
    required this.puzzle,
    required this.foundWords,
    required this.onWordFound,
    this.hintCells = const {},
  });

  final WordSearchPuzzle puzzle;
  final Set<PlacedWord> foundWords;
  final void Function(PlacedWord found) onWordFound;

  /// Cells to briefly highlight as a hint — purely visual, the screen owns
  /// clearing this after a short delay.
  final Set<GridPos> hintCells;

  @override
  State<WordSearchGrid> createState() => _WordSearchGridState();
}

class _WordSearchGridState extends State<WordSearchGrid> {
  List<GridPos> _selection = const [];
  bool _wrongFlash = false;
  Timer? _wrongFlashTimer;

  @override
  void dispose() {
    _wrongFlashTimer?.cancel();
    super.dispose();
  }

  GridPos? _cellAt(Offset local, double cellSize) {
    final row = (local.dy / cellSize).floor();
    final col = (local.dx / cellSize).floor();
    final size = widget.puzzle.size;
    if (row < 0 || row >= size || col < 0 || col >= size) return null;
    return GridPos(row, col);
  }

  /// Snaps the raw pointer cell to the nearest of the 8 straight directions
  /// from the selection's start cell, and walks as far as the pointer's
  /// distance suggests (clipped to the grid) — forgiving of an imprecise
  /// drag rather than rejecting anything not perfectly diagonal.
  List<GridPos> _straightPath(GridPos start, GridPos end) {
    final dr = end.row - start.row;
    final dc = end.col - start.col;
    if (dr == 0 && dc == 0) return [start];

    final angle = atan2(dr.toDouble(), dc.toDouble());
    var octant = (angle / (pi / 4)).round() % 8;
    if (octant < 0) octant += 8;
    final dir = _octantDirections[octant];
    final length = max(dr.abs(), dc.abs());

    final size = widget.puzzle.size;
    final path = <GridPos>[];
    for (var i = 0; i <= length; i++) {
      final r = start.row + dir.$1 * i;
      final c = start.col + dir.$2 * i;
      if (r < 0 || r >= size || c < 0 || c >= size) break;
      path.add(GridPos(r, c));
    }
    return path;
  }

  bool _sameCells(List<GridPos> a, List<GridPos> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _handleStart(Offset local, double cellSize) {
    final cell = _cellAt(local, cellSize);
    if (cell == null) return;
    setState(() {
      _selection = [cell];
      _wrongFlash = false;
    });
  }

  void _handleUpdate(Offset local, double cellSize) {
    if (_selection.isEmpty) return;
    final cell = _cellAt(local, cellSize);
    if (cell == null) return;
    setState(() => _selection = _straightPath(_selection.first, cell));
  }

  void _handleEnd() {
    final selection = _selection;
    if (selection.length < 2) {
      setState(() => _selection = const []);
      return;
    }

    final reversed = selection.reversed.toList();
    PlacedWord? match;
    for (final placed in widget.puzzle.placedWords) {
      if (widget.foundWords.contains(placed)) continue;
      if (_sameCells(placed.cells, selection) ||
          _sameCells(placed.cells, reversed)) {
        match = placed;
        break;
      }
    }

    if (match != null) {
      HapticFeedback.lightImpact();
      SoundService.instance.playCorrect();
      widget.onWordFound(match);
      setState(() => _selection = const []);
    } else {
      HapticFeedback.mediumImpact();
      SoundService.instance.playIncorrect();
      setState(() => _wrongFlash = true);
      _wrongFlashTimer?.cancel();
      _wrongFlashTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _wrongFlash = false;
          _selection = const [];
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;
    final colors = Theme.of(context).colorScheme;

    final foundCells = <GridPos>{
      for (final w in widget.foundWords) ...w.cells,
    };
    final selectedCells = _selection.toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = (available / puzzle.size).clamp(_kMinCell, _kMaxCell);
        final side = cellSize * puzzle.size;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              onPanStart: (d) => _handleStart(d.localPosition, cellSize),
              onPanUpdate: (d) => _handleUpdate(d.localPosition, cellSize),
              onPanEnd: (_) => _handleEnd(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < puzzle.size; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < puzzle.size; c++)
                          _Cell(
                            letter: puzzle.grid[r][c],
                            size: cellSize,
                            isFound: foundCells.contains(GridPos(r, c)),
                            isSelected: selectedCells.contains(GridPos(r, c)),
                            isHint: widget.hintCells.contains(GridPos(r, c)),
                            isWrong: _wrongFlash &&
                                selectedCells.contains(GridPos(r, c)),
                            accentColor: colors.primary,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.letter,
    required this.size,
    required this.isFound,
    required this.isSelected,
    required this.isHint,
    required this.isWrong,
    required this.accentColor,
  });

  final String letter;
  final double size;
  final bool isFound;
  final bool isSelected;
  final bool isHint;
  final bool isWrong;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = Theme.of(context).colorScheme.onSurface;

    if (isWrong) {
      bg = AppPalette.incorrectRed.withValues(alpha: 0.35);
      fg = AppPalette.cardStock;
    } else if (isFound) {
      bg = AppPalette.correctGold.withValues(alpha: 0.35);
      fg = AppPalette.ink;
    } else if (isSelected) {
      bg = accentColor.withValues(alpha: 0.55);
      fg = AppPalette.cardStock;
    } else if (isHint) {
      bg = AppPalette.mutedGold.withValues(alpha: 0.4);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
