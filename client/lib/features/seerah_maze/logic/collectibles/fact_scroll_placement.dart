import '../../models/maze_cell.dart';
import '../maze_generator.dart';

/// B4 — picks the dead-end cell a level's one collectible fact scroll
/// sits on.
///
/// Every level gets exactly one scroll, tied to that level's own Seerah
/// milestone (see data/maze_facts.dart), so this just needs to find
/// *somewhere* valid to put it rather than solve a placement puzzle like
/// A3's doors or A5's teleports — a scroll is a pure collectible with no
/// effect on movement, so there's nothing to validate for solvability.
///
/// Deterministic: dead ends are scanned in row-major order and the
/// farthest-from-start one not already claimed by a star/key/orb/tent is
/// picked — the same farthest-first, row-major tie-break
/// MazeGenerator._placeStars already uses, so a level's scroll position
/// is fixed by its seed like everything else.
MazeCoord? placeFactScroll({
  required MazeGenerationResult maze,
  Set<MazeCoord> reserved = const {},
}) {
  MazeCoord? best;
  var bestDistance = -1;
  for (var row = 0; row < maze.size; row++) {
    for (var col = 0; col < maze.size; col++) {
      final coord = MazeCoord(row, col);
      if (coord == maze.start || coord == maze.destination) continue;
      if (reserved.contains(coord) || maze.starCoords.contains(coord)) continue;
      if (maze.cellAt(coord).openDirections.length != 1) continue;
      final distance = maze.distancesFromStart[row][col];
      if (distance > bestDistance) {
        bestDistance = distance;
        best = coord;
      }
    }
  }
  return best;
}
