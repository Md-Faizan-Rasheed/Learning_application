import '../../models/maze_cell.dart';
import '../../models/maze_direction.dart';
import '../../models/maze_door.dart';
import '../../models/maze_passage_edge.dart';
import '../maze_generator.dart';

/// The doors and keys placed on one level, plus the live state of which
/// keys the player is carrying and which doors they've already opened.
///
/// A3's load-bearing rule is that a level must stay finishable: every key
/// has to be reachable *before* the door it opens. Rather than trusting
/// the placement heuristic to get that right, [isSolvable] proves it
/// directly with a progressive-reachability search, and [place] refuses to
/// emit a layout that doesn't pass — so an unsolvable door layout can't
/// reach a player even if the placement logic is later changed.
///
/// Pure Dart, no `dart:ui`: the placement and the proof are both directly
/// unit-testable.
class DoorsAndKeys {
  DoorsAndKeys({required Set<MazeDoor> doors, required Map<MazeCoord, MazeKeyKind> keys})
      : doors = Set.unmodifiable(doors),
        keys = Map.unmodifiable(keys);

  /// An empty set — for levels that don't use the mechanic.
  factory DoorsAndKeys.none() => DoorsAndKeys(doors: const {}, keys: const {});

  final Set<MazeDoor> doors;

  /// Key cell -> which kind of key sits there.
  final Map<MazeCoord, MazeKeyKind> keys;

  final Set<MazeKeyKind> _held = {};
  final Set<MazeCoord> _collectedKeyCells = {};

  bool get isEmpty => doors.isEmpty && keys.isEmpty;

  Set<MazeKeyKind> get heldKeys => Set.unmodifiable(_held);

  /// Key cells not yet picked up, for the painter.
  Map<MazeCoord, MazeKeyKind> get remainingKeys => Map.unmodifiable({
        for (final entry in keys.entries)
          if (!_collectedKeyCells.contains(entry.key)) entry.key: entry.value,
      });

  /// Doors the player still can't walk through.
  Set<MazeDoor> get lockedDoors =>
      Set.unmodifiable(doors.where((d) => !_held.contains(d.keyKind)).toSet());

  /// The door on the passage from [from] in [direction], if any.
  MazeDoor? doorOn(MazeCoord from, MazeDirection direction) {
    if (doors.isEmpty) return null;
    final edge = MazePassageEdge(from, direction);
    for (final door in doors) {
      if (door.edge == edge) return door;
    }
    return null;
  }

  /// Whether the player may currently cross the passage from [from] in
  /// [direction] — false only when a door sits there and its key isn't
  /// held yet. This is the single predicate the solver and the controller
  /// both consult, so "what the hint shows" and "where you can walk" can
  /// never disagree.
  bool canPass(MazeCoord from, MazeDirection direction) {
    final door = doorOn(from, direction);
    return door == null || _held.contains(door.keyKind);
  }

  /// Picks up a key if one sits on [coord]. Returns the kind collected, or
  /// null if there was nothing there (or it was already taken).
  MazeKeyKind? collectKeyAt(MazeCoord coord) {
    final kind = keys[coord];
    if (kind == null || !_collectedKeyCells.add(coord)) return null;
    _held.add(kind);
    return kind;
  }

  /// Drops every key and re-locks every door, for a level restart.
  void reset() {
    _held.clear();
    _collectedKeyCells.clear();
  }

  // ---- Placement and the solvability proof ----

  /// Proves a door/key layout leaves [maze] finishable, by repeatedly
  /// flood-filling from the start with the keys currently in hand and
  /// picking up any key that fill can touch:
  ///
  ///   reach -> collect newly reachable keys -> reach again -> ...
  ///
  /// If the destination ever falls inside the reachable region, the level
  /// is finishable. If a pass adds no new key and still hasn't reached the
  /// destination, the player would be stuck, so the layout is rejected.
  /// This handles chained dependencies (a brass key behind a copper door)
  /// correctly, which a simple "key before door on the solution path"
  /// check would not.
  static bool isSolvable({
    required MazeGenerationResult maze,
    required Set<MazeDoor> doors,
    required Map<MazeCoord, MazeKeyKind> keys,
  }) {
    final held = <MazeKeyKind>{};
    final collected = <MazeCoord>{};

    while (true) {
      final reachable = _reachableWith(maze: maze, doors: doors, held: held);
      if (reachable.contains(maze.destination)) return true;

      var foundNewKey = false;
      for (final entry in keys.entries) {
        if (collected.contains(entry.key)) continue;
        if (!reachable.contains(entry.key)) continue;
        collected.add(entry.key);
        held.add(entry.value);
        foundNewKey = true;
      }
      if (!foundNewKey) return false;
    }
  }

  /// Every cell reachable from the maze start while [held] keys are in
  /// hand (so doors whose key is held are walked straight through).
  static Set<MazeCoord> _reachableWith({
    required MazeGenerationResult maze,
    required Set<MazeDoor> doors,
    required Set<MazeKeyKind> held,
  }) {
    final blocked = <MazePassageEdge>{
      for (final door in doors)
        if (!held.contains(door.keyKind)) door.edge,
    };

    final seen = <MazeCoord>{maze.start};
    final queue = <MazeCoord>[maze.start];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      final cell = maze.cellAt(current);
      for (final direction in MazeDirection.values) {
        if (!cell.isOpen(direction)) continue;
        final next = MazeCoord(
          current.row + direction.deltaRow,
          current.col + direction.deltaCol,
        );
        if (!maze.inBounds(next) || seen.contains(next)) continue;
        if (blocked.contains(MazePassageEdge(current, direction))) continue;
        seen.add(next);
        queue.add(next);
      }
    }
    return seen;
  }

  /// Places up to [doorCount] doors on the level's solution path, each with
  /// its key somewhere the player can already get to.
  ///
  /// Deterministic: the candidate passages are taken from the solution
  /// path in order and the key is chosen as the farthest-from-start cell of
  /// the region before the door, with a row-major tie-break — no RNG, so
  /// the same level always has the same doors. Every candidate layout is
  /// run through [isSolvable] before being accepted, and anything that
  /// fails is skipped rather than shipped.
  static DoorsAndKeys place({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required int doorCount,
  }) {
    if (doorCount < 1 || solutionPath.length < 4) return DoorsAndKeys.none();

    final doors = <MazeDoor>{};
    final keys = <MazeCoord, MazeKeyKind>{};
    const kinds = MazeKeyKind.values;

    // Spread the doors along the path rather than bunching them at the
    // start: aim for 1/(n+1), 2/(n+1) ... of the way along.
    final wanted = doorCount.clamp(1, kinds.length);
    for (var i = 1; i <= wanted; i++) {
      final index = (solutionPath.length * i) ~/ (wanted + 1);
      if (index < 1 || index >= solutionPath.length) continue;

      final before = solutionPath[index - 1];
      final after = solutionPath[index];
      final direction = _directionBetween(before, after);
      if (direction == null) continue;

      final kind = kinds[(i - 1) % kinds.length];
      final candidateDoor = MazeDoor(edge: MazePassageEdge(before, direction), keyKind: kind);
      if (doors.any((d) => d.edge == candidateDoor.edge)) continue;

      // Where can the player get to with this door (and all the earlier
      // ones) closed? The key has to live in there.
      final trialDoors = {...doors, candidateDoor};
      final reachable = _reachableWith(
        maze: maze,
        doors: trialDoors,
        held: const {},
      );
      final keyCell = _pickKeyCell(
        maze: maze,
        candidates: reachable,
        taken: keys.keys.toSet(),
      );
      if (keyCell == null) continue;

      final trialKeys = {...keys, keyCell: kind};
      if (!isSolvable(maze: maze, doors: trialDoors, keys: trialKeys)) continue;

      doors.add(candidateDoor);
      keys[keyCell] = kind;
    }

    return DoorsAndKeys(doors: doors, keys: keys);
  }

  /// The farthest-from-start cell among [candidates] that isn't the start,
  /// the destination, a collectible star, or already holding a key — so a
  /// key is a small detour worth making rather than something you trip
  /// over on the way. Row-major tie-break keeps it deterministic.
  static MazeCoord? _pickKeyCell({
    required MazeGenerationResult maze,
    required Set<MazeCoord> candidates,
    required Set<MazeCoord> taken,
  }) {
    MazeCoord? best;
    var bestDistance = -1;
    for (final coord in candidates) {
      if (coord == maze.start || coord == maze.destination) continue;
      if (taken.contains(coord) || maze.starCoords.contains(coord)) continue;
      final distance = maze.distancesFromStart[coord.row][coord.col];
      if (distance > bestDistance ||
          (distance == bestDistance &&
              best != null &&
              (coord.row < best.row || (coord.row == best.row && coord.col < best.col)))) {
        bestDistance = distance;
        best = coord;
      }
    }
    return best;
  }

  static MazeDirection? _directionBetween(MazeCoord from, MazeCoord to) {
    for (final direction in MazeDirection.values) {
      if (from.row + direction.deltaRow == to.row && from.col + direction.deltaCol == to.col) {
        return direction;
      }
    }
    return null;
  }
}
