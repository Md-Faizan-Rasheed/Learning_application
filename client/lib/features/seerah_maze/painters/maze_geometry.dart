import 'dart:ui';

import '../models/maze_cell.dart';

/// Converts grid coordinates to pixel geometry for a given cell size —
/// shared by every painter and by the board widget's own hit-testing, so
/// "where is cell (r,c) on screen" is computed exactly one way. Lives in
/// painters/ (not logic/) specifically because it needs dart:ui's
/// Offset/Rect — the logic/ layer stays entirely free of any UI-adjacent
/// dependency, per the feature's "pure Dart, UI-independent game logic"
/// design.
class MazeGeometry {
  const MazeGeometry({required this.cellSize, this.origin = Offset.zero});

  final double cellSize;
  final Offset origin;

  Offset centerOf(MazeCoord coord) => Offset(
        origin.dx + (coord.col + 0.5) * cellSize,
        origin.dy + (coord.row + 0.5) * cellSize,
      );

  Rect rectOf(MazeCoord coord) => Rect.fromLTWH(
        origin.dx + coord.col * cellSize,
        origin.dy + coord.row * cellSize,
        cellSize,
        cellSize,
      );

  /// The grid cell containing [point], not clamped to the maze's own
  /// bounds — callers compare against the grid size themselves.
  MazeCoord coordAt(Offset point) {
    final col = ((point.dx - origin.dx) / cellSize).floor();
    final row = ((point.dy - origin.dy) / cellSize).floor();
    return MazeCoord(row, col);
  }
}
