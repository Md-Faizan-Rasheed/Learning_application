import 'maze_cell.dart';
import 'maze_direction.dart';

/// The identity of one passage *between* two cells, rather than of a cell.
///
/// The same passage can be approached from either side, so every edge is
/// stored in one canonical form — the upper/left cell, facing east or
/// south — which makes `==`/`hashCode` (and therefore set lookup) agree no
/// matter which way the player walks into it. Without that normalization a
/// mechanic sitting on a passage would only be recognised from one side.
///
/// Shared by A3's locked doors and A7's shifting walls, both of which
/// attach to a passage rather than to a cell.
class MazePassageEdge {
  /// Normalizes [from] + [direction] to the canonical (upper/left cell,
  /// east-or-south) representation of the same passage.
  factory MazePassageEdge(MazeCoord from, MazeDirection direction) {
    if (direction == MazeDirection.east || direction == MazeDirection.south) {
      return MazePassageEdge._(from, direction);
    }
    final neighbor = MazeCoord(
      from.row + direction.deltaRow,
      from.col + direction.deltaCol,
    );
    return MazePassageEdge._(neighbor, direction.opposite);
  }

  const MazePassageEdge._(this.cell, this.direction);

  /// The upper/left side of the passage.
  final MazeCoord cell;

  /// Always [MazeDirection.east] or [MazeDirection.south], pointing at the
  /// other side.
  final MazeDirection direction;

  /// The lower/right side of the passage.
  MazeCoord get otherCell => MazeCoord(
        cell.row + direction.deltaRow,
        cell.col + direction.deltaCol,
      );

  /// Whether this edge is the passage between [a] and [b], either way
  /// round.
  bool connects(MazeCoord a, MazeCoord b) =>
      (cell == a && otherCell == b) || (cell == b && otherCell == a);

  @override
  bool operator ==(Object other) =>
      other is MazePassageEdge && other.cell == cell && other.direction == direction;

  @override
  int get hashCode => Object.hash(cell, direction);

  @override
  String toString() => 'MazePassageEdge($cell -> ${direction.name})';
}
