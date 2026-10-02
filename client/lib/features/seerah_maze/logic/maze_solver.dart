import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import 'maze_generator.dart';

/// Whether the passage leaving [from] in [direction] may currently be
/// crossed. Lets mechanics that block an already-open passage (A3's locked
/// doors, and later one-way cells) restrict pathfinding without the solver
/// knowing what a door is.
typedef MazePassageRule = bool Function(MazeCoord from, MazeDirection direction);

/// Where a move from [from] in [direction] actually lands, for mechanics
/// that carry the player past the adjacent cell (A4's slippery sand, and
/// later A5's teleports). Returning null means "just the adjacent cell",
/// which is the ordinary case.
typedef MazeLandingRule = MazeCoord? Function(MazeCoord from, MazeDirection direction);

/// Shortest-path queries over a generated maze — shared by the hint system
/// and the drag-follow control (both need "shortest open-passage route
/// between two cells"), and the only place that logic lives.
class MazeSolver {
  const MazeSolver();

  /// BFS shortest path from [from] to [to], walking open passages only.
  /// Returns both endpoints inclusive (a path to the current cell is
  /// `[from]`, length 1), or null if [to] is unreachable — never happens
  /// on a maze built by MazeGenerator (every cell is connected), but a
  /// caller fed an arbitrary maze should still handle it.
  ///
  /// [canPass], when given, additionally rules out passages a mechanic is
  /// currently blocking; omitted, every open passage is walkable, which is
  /// the original Phase 1 behavior. [landingFor] lets a mechanic carry the
  /// player past the adjacent cell, in which case the returned path lists
  /// the cells *landed on* — one entry per move, not per cell crossed.
  List<MazeCoord>? shortestPath(
    MazeGenerationResult maze,
    MazeCoord from,
    MazeCoord to, {
    MazePassageRule? canPass,
    MazeLandingRule? landingFor,
  }) {
    if (from == to) return [from];

    final size = maze.size;
    final visited = List.generate(size, (_) => List.filled(size, false));
    final cameFrom = <MazeCoord, MazeCoord>{};
    visited[from.row][from.col] = true;
    final queue = <MazeCoord>[from];
    var head = 0;

    while (head < queue.length) {
      final current = queue[head++];
      if (current == to) {
        return _reconstructPath(cameFrom, from, to);
      }
      final cell = maze.cellAt(current);
      for (final direction in MazeDirection.values) {
        if (!cell.isOpen(direction)) continue;
        if (canPass != null && !canPass(current, direction)) continue;
        final next = landingFor?.call(current, direction) ??
            MazeCoord(
              current.row + direction.deltaRow,
              current.col + direction.deltaCol,
            );
        if (!maze.inBounds(next) || visited[next.row][next.col]) continue;
        visited[next.row][next.col] = true;
        cameFrom[next] = current;
        queue.add(next);
      }
    }
    return null;
  }

  /// Number of open-passage steps from [from] to [to], or -1 if
  /// unreachable.
  int distance(
    MazeGenerationResult maze,
    MazeCoord from,
    MazeCoord to, {
    MazePassageRule? canPass,
    MazeLandingRule? landingFor,
  }) {
    final path = shortestPath(maze, from, to, canPass: canPass, landingFor: landingFor);
    return path == null ? -1 : path.length - 1;
  }

  List<MazeCoord> _reconstructPath(
    Map<MazeCoord, MazeCoord> cameFrom,
    MazeCoord from,
    MazeCoord to,
  ) {
    final path = <MazeCoord>[to];
    var current = to;
    while (current != from) {
      current = cameFrom[current]!;
      path.add(current);
    }
    return path.reversed.toList();
  }
}
