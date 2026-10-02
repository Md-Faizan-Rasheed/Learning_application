import 'maze_direction.dart';

/// A single grid coordinate, row-major (row 0 = top, col 0 = left) — always
/// in physical/absolute terms, never direction-aware, so maze geometry is
/// the same regardless of the app's text direction (RTL locales mirror the
/// surrounding UI chrome, never the maze itself).
class MazeCoord {
  const MazeCoord(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) => other is MazeCoord && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'MazeCoord($row, $col)';
}

/// One cell of a generated maze: which of its four walls are open
/// passages. Immutable — a generator builds every cell's final open set
/// before constructing it, rather than mutating cells in place, so a
/// finished [MazeGenerationResult] can never be accidentally altered by
/// later game logic.
class MazeCell {
  MazeCell({required this.coord, required Set<MazeDirection> open})
      : openDirections = Set.unmodifiable(open);

  final MazeCoord coord;
  final Set<MazeDirection> openDirections;

  bool isOpen(MazeDirection direction) => openDirections.contains(direction);
}
