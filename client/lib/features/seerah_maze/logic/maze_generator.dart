import 'dart:math';

import '../constants/maze_constants.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';

/// A fully generated, immutable maze: the grid itself plus the derived
/// start/destination/collectible positions a level actually plays with.
class MazeGenerationResult {
  const MazeGenerationResult({
    required this.size,
    required this.cells,
    required this.start,
    required this.destination,
    required this.starCoords,
    required this.distancesFromStart,
  });

  final int size;

  /// Row-major grid: `cells[row][col]`.
  final List<List<MazeCell>> cells;

  final MazeCoord start;
  final MazeCoord destination;

  /// Collectible star positions (dead-end cells) — up to
  /// [MazeConstants.collectibleStarCount], fewer only if the maze doesn't
  /// have that many dead ends.
  final List<MazeCoord> starCoords;

  /// BFS distance (open-passage steps) from [start] to every cell, already
  /// computed once while deriving [destination] — exposed so a one-time,
  /// level-start visual (the board's staggered "walls build outward" reveal)
  /// can reuse it instead of recomputing BFS distances itself.
  final List<List<int>> distancesFromStart;

  MazeCell cellAt(MazeCoord coord) => cells[coord.row][coord.col];

  bool inBounds(MazeCoord coord) =>
      coord.row >= 0 && coord.row < size && coord.col >= 0 && coord.col < size;

  bool isOpen(MazeCoord from, MazeDirection direction) => cellAt(from).isOpen(direction);

  /// The neighbor reachable from [from] through [direction], or null if
  /// that wall is closed (or it would leave the grid).
  MazeCoord? neighborThrough(MazeCoord from, MazeDirection direction) {
    if (!isOpen(from, direction)) return null;
    final next = MazeCoord(from.row + direction.deltaRow, from.col + direction.deltaCol);
    return inBounds(next) ? next : null;
  }
}

/// Builds deterministic perfect mazes via an iterative recursive-backtracker
/// (DFS), then derives the destination (farthest cell from the start, by
/// BFS distance — not just the opposite corner) and places collectible
/// stars at dead ends. Pure Dart, no Flutter dependency, so it's trivially
/// unit-testable.
class MazeGenerator {
  const MazeGenerator();

  /// [seed] fully determines the result: the same seed and size always
  /// produce byte-for-byte the same maze (same start/destination/open
  /// walls/star placement) on this Dart version. [extraLoopCount] knocks
  /// out that many additional, currently-closed walls after the perfect
  /// maze is carved, deterministically, giving larger/later levels more
  /// than one valid route.
  MazeGenerationResult generate({
    required int size,
    required int seed,
    int extraLoopCount = 0,
  }) {
    assert(size >= 2, 'a maze needs at least a 2x2 grid');
    final random = Random(seed);
    final open = List.generate(
      size,
      (_) => List.generate(size, (_) => <MazeDirection>{}),
    );

    const start = MazeCoord(0, 0);
    _carvePerfectMaze(open: open, size: size, start: start, random: random);

    if (extraLoopCount > 0) {
      _addLoops(open: open, size: size, count: extraLoopCount, random: random);
    }

    final cells = List.generate(
      size,
      (row) => List.generate(
        size,
        (col) => MazeCell(coord: MazeCoord(row, col), open: open[row][col]),
      ),
    );

    final distances = _bfsDistances(cells: cells, size: size, from: start);
    final destination = _farthestCell(distances: distances, size: size);
    final starCoords = _placeStars(
        cells: cells, size: size, start: start, destination: destination, distances: distances);

    return MazeGenerationResult(
      size: size,
      cells: cells,
      start: start,
      destination: destination,
      starCoords: starCoords,
      distancesFromStart: distances,
    );
  }

  void _carvePerfectMaze({
    required List<List<Set<MazeDirection>>> open,
    required int size,
    required MazeCoord start,
    required Random random,
  }) {
    final visited = List.generate(size, (_) => List.filled(size, false));
    visited[start.row][start.col] = true;
    final stack = <MazeCoord>[start];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final unvisitedNeighbors = <(MazeDirection, MazeCoord)>[];
      for (final direction in MazeDirection.values) {
        final next = MazeCoord(
          current.row + direction.deltaRow,
          current.col + direction.deltaCol,
        );
        if (next.row < 0 || next.row >= size || next.col < 0 || next.col >= size) {
          continue;
        }
        if (!visited[next.row][next.col]) {
          unvisitedNeighbors.add((direction, next));
        }
      }

      if (unvisitedNeighbors.isEmpty) {
        stack.removeLast();
        continue;
      }

      final (direction, next) = unvisitedNeighbors[random.nextInt(unvisitedNeighbors.length)];
      open[current.row][current.col].add(direction);
      open[next.row][next.col].add(direction.opposite);
      visited[next.row][next.col] = true;
      stack.add(next);
    }
  }

  /// Opens [count] additional, currently-closed walls between adjacent
  /// cells, chosen via a deterministic partial Fisher-Yates shuffle (seeded
  /// by the same [random]) over every closed adjacent pair — so which
  /// walls fall is still fully determined by the seed.
  void _addLoops({
    required List<List<Set<MazeDirection>>> open,
    required int size,
    required int count,
    required Random random,
  }) {
    final candidates = <(MazeCoord, MazeDirection, MazeCoord)>[];
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final coord = MazeCoord(row, col);
        // Only consider east/south to avoid listing each pair twice.
        for (final direction in [MazeDirection.east, MazeDirection.south]) {
          final next = MazeCoord(row + direction.deltaRow, col + direction.deltaCol);
          if (next.row >= size || next.col >= size) continue;
          if (!open[row][col].contains(direction)) {
            candidates.add((coord, direction, next));
          }
        }
      }
    }

    final picks = min(count, candidates.length);
    for (var i = 0; i < picks; i++) {
      final j = i + random.nextInt(candidates.length - i);
      final tmp = candidates[i];
      candidates[i] = candidates[j];
      candidates[j] = tmp;
      final (coord, direction, next) = candidates[i];
      open[coord.row][coord.col].add(direction);
      open[next.row][next.col].add(direction.opposite);
    }
  }

  List<List<int>> _bfsDistances({
    required List<List<MazeCell>> cells,
    required int size,
    required MazeCoord from,
  }) {
    final distances = List.generate(size, (_) => List.filled(size, -1));
    distances[from.row][from.col] = 0;
    final queue = <MazeCoord>[from];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      final currentDistance = distances[current.row][current.col];
      final cell = cells[current.row][current.col];
      for (final direction in MazeDirection.values) {
        if (!cell.isOpen(direction)) continue;
        final next = MazeCoord(
          current.row + direction.deltaRow,
          current.col + direction.deltaCol,
        );
        if (distances[next.row][next.col] != -1) continue;
        distances[next.row][next.col] = currentDistance + 1;
        queue.add(next);
      }
    }
    return distances;
  }

  /// Among all cells, the one with the greatest BFS distance from the
  /// start. Ties break in row-major order for determinism.
  MazeCoord _farthestCell({required List<List<int>> distances, required int size}) {
    var best = const MazeCoord(0, 0);
    var bestDistance = -1;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (distances[row][col] > bestDistance) {
          bestDistance = distances[row][col];
          best = MazeCoord(row, col);
        }
      }
    }
    return best;
  }

  /// Dead-end cells (exactly one open wall), excluding the start and
  /// destination, farthest-from-start first — up to
  /// [MazeConstants.collectibleStarCount] of them.
  List<MazeCoord> _placeStars({
    required List<List<MazeCell>> cells,
    required int size,
    required MazeCoord start,
    required MazeCoord destination,
    required List<List<int>> distances,
  }) {
    final deadEnds = <MazeCoord>[];
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final coord = MazeCoord(row, col);
        if (coord == start || coord == destination) continue;
        if (cells[row][col].openDirections.length == 1) deadEnds.add(coord);
      }
    }
    // Farthest-first, with an explicit row-then-col tie-break so placement
    // is deterministic regardless of whether List.sort happens to be
    // stable for equal-distance cells.
    deadEnds.sort((a, b) {
      final byDistance = distances[b.row][b.col].compareTo(distances[a.row][a.col]);
      if (byDistance != 0) return byDistance;
      final byRow = a.row.compareTo(b.row);
      if (byRow != 0) return byRow;
      return a.col.compareTo(b.col);
    });
    return deadEnds.take(MazeConstants.collectibleStarCount).toList();
  }
}
