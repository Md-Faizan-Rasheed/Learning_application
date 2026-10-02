import '../../models/maze_cell.dart';
import '../../models/maze_direction.dart';
import '../../models/maze_passage_edge.dart';
import '../maze_generator.dart';
import 'doors_and_keys.dart';
import 'obstacle_field.dart';
import 'shifting_walls.dart';
import 'teleport_network.dart';

/// Where one move actually takes the player.
///
/// With A4's sand in play a single move is no longer a single cell step:
/// stepping onto sand slides you onward. So a move resolves to the whole
/// run of cells entered, in order, which lets the caller animate the slide
/// and collect everything passed over — while [landing] is the cell the
/// player ends up on.
class MazeMoveResult {
  MazeMoveResult(List<MazeCoord> path)
      : assert(path.isNotEmpty, 'a move that happened entered at least one cell'),
        path = List.unmodifiable(path),
        teleportedFrom = null;

  MazeMoveResult._(List<MazeCoord> path, {required this.teleportedFrom})
      : path = List.unmodifiable(path);

  /// Cells entered by this move, in order. Excludes the cell moved from.
  final List<MazeCoord> path;

  /// A5 — the tent the player jumped from, when this move ended in a
  /// teleport. Null for an ordinary move, which is what the board checks
  /// to decide whether to play the fade/scale jump.
  final MazeCoord? teleportedFrom;

  MazeCoord get landing => path.last;

  /// True when sand carried the player more than one cell.
  bool get isSlide => path.length > 1 && teleportedFrom == null;

  bool get isTeleport => teleportedFrom != null;

  MazeMoveResult withTeleport({required MazeCoord from, required MazeCoord to}) =>
      MazeMoveResult._([...path, to], teleportedFrom: from);
}

/// A4 — the one place that answers "may the player move this way, and
/// where do they end up".
///
/// Doors (A3), one-way arrow tiles and slippery sand (A4) all fold into
/// this single resolver, so the controller, the pathfinder and the
/// solvability validator can never disagree about what a legal move is.
/// Adding a mechanic that bends movement means teaching this class, not
/// hunting down every caller.
///
/// Pure Dart and immutable apart from the door state it borrows, so the
/// whole movement model is directly unit-testable.
class MazeMovementRules {
  const MazeMovementRules({
    required this.maze,
    this.doors,
    this.teleports,
    this.obstacles,
    this.shiftingWalls,
    this.oneWayArrows = const {},
    this.sandCells = const {},
    this.useTeleportCooldown = true,
    this.respectObstacles = true,
  });

  final MazeGenerationResult maze;

  /// A3's locked doors, if this level has them.
  final DoorsAndKeys? doors;

  /// A5's linked tents, if this level has them.
  final TeleportNetwork? teleports;

  /// Whether to honor the teleport cooldown. The live game does; the
  /// pathfinder and the solvability checks don't, because a cooldown only
  /// ever delays a jump and so can't change what's ultimately reachable.
  final bool useTeleportCooldown;

  /// A6's moving obstacles, if this level has them.
  final ObstacleField? obstacles;

  /// A7's shifting walls, if this level has them. Unlike the sandstorm,
  /// these *are* honored by the pathfinder: a closure lasts long enough
  /// (15s by default) that routing a hint through one would be unhelpful,
  /// so hints route around a currently-shut passage instead.
  final ShiftingWalls? shiftingWalls;

  /// Whether a sandstorm currently blocks entry. True in the live game;
  /// false for analysis, for the same reason as the teleport cooldown —
  /// every closure always clears again, so the storm can only delay the
  /// player, never change what's reachable. Counting it would make hints
  /// and the solvability checks flicker with the weather.
  final bool respectObstacles;

  /// A4 — cell -> the single direction you're allowed to leave it in.
  final Map<MazeCoord, MazeDirection> oneWayArrows;

  /// A4 — cells that slide the player onward.
  final Set<MazeCoord> sandCells;

  bool get isPlain =>
      doors == null && oneWayArrows.isEmpty && sandCells.isEmpty && (teleports?.isEmpty ?? true);

  bool isSand(MazeCoord coord) => sandCells.contains(coord);

  MazeDirection? arrowAt(MazeCoord coord) => oneWayArrows[coord];

  /// Whether the player may leave [from] heading [direction] — false if the
  /// wall is closed, a locked door bars it, or [from] is an arrow tile
  /// pointing somewhere else.
  bool canPass(MazeCoord from, MazeDirection direction) {
    if (!maze.inBounds(from)) return false;
    if (!maze.cellAt(from).isOpen(direction)) return false;
    // A7 — a shifting wall closes a passage the maze itself calls open.
    if (shiftingWalls?.isClosedPassage(from, direction) ?? false) return false;
    final next = MazeCoord(from.row + direction.deltaRow, from.col + direction.deltaCol);
    if (!maze.inBounds(next)) return false;
    if (doors != null && !doors!.canPass(from, direction)) return false;
    // An arrow tile commits you to its direction; that's what "blocks
    // backward movement" means in practice.
    final arrow = oneWayArrows[from];
    if (arrow != null && arrow != direction) return false;
    // A6 — a cell the sandstorm has closed can't be walked into.
    if (respectObstacles && (obstacles?.blocks(next) ?? false)) return false;
    return true;
  }

  /// Resolves a move from [from] in [direction] to the run of cells it
  /// actually covers, or null if the move isn't legal at all.
  ///
  /// Sand keeps carrying the player in the same direction until something
  /// stops them: a wall, a locked door, an arrow pointing elsewhere, or
  /// reaching solid ground. The slide is bounded by the grid, and each
  /// step strictly advances in one direction, so it always terminates.
  MazeMoveResult? resolveMove(MazeCoord from, MazeDirection direction) {
    if (!canPass(from, direction)) return null;

    final path = <MazeCoord>[];
    var current = MazeCoord(from.row + direction.deltaRow, from.col + direction.deltaCol);
    path.add(current);

    // Only sand keeps you going; landing on solid ground ends the move.
    while (isSand(current) && canPass(current, direction)) {
      current = MazeCoord(current.row + direction.deltaRow, current.col + direction.deltaCol);
      path.add(current);
      // Defensive: a grid this size can never produce a longer run, so a
      // longer one would mean a logic error rather than a real slide.
      if (path.length > maze.size * maze.size) break;
    }

    final result = MazeMoveResult(path);

    // A5 — a tent the player has just *walked* onto carries them to its
    // partner. Arriving by teleport never re-triggers (the jump isn't
    // resolved recursively), which is what makes ping-pong structurally
    // impossible rather than merely timed out.
    final network = teleports;
    if (network != null && !network.isEmpty) {
      final partner = useTeleportCooldown
          ? network.activePartnerFor(result.landing)
          : network.partnerFor(result.landing);
      if (partner != null) {
        return result.withTeleport(from: result.landing, to: partner);
      }
    }
    return result;
  }

  /// Every legal move out of [from], as (direction, landing cell).
  List<(MazeDirection, MazeCoord)> movesFrom(MazeCoord from) {
    final moves = <(MazeDirection, MazeCoord)>[];
    for (final direction in MazeDirection.values) {
      final result = resolveMove(from, direction);
      if (result != null) moves.add((direction, result.landing));
    }
    return moves;
  }

  /// The cooldown-free view of these rules, used for every reachability
  /// question. A cooldown only ever postpones a jump the player can still
  /// make a moment later, so counting it would wrongly report cells as
  /// unreachable.
  MazeMovementRules get _forAnalysis => (useTeleportCooldown || respectObstacles)
      ? copyWith(useTeleportCooldown: false, respectObstacles: false)
      : this;

  /// Every cell the player could ever get to from [start], following the
  /// movement rules as they stand right now.
  Set<MazeCoord> reachableFrom(MazeCoord start) {
    final rules = _forAnalysis;
    final seen = <MazeCoord>{start};
    final queue = <MazeCoord>[start];
    var head = 0;
    while (head < queue.length) {
      for (final (_, landing) in rules.movesFrom(queue[head++])) {
        if (seen.add(landing)) queue.add(landing);
      }
    }
    return seen;
  }

  /// The no-softlock proof A4 needs.
  ///
  /// One-way tiles make reachability directional: being able to get
  /// *into* a region no longer means being able to get out of it, so a
  /// plain "is the goal reachable from the start" check is not enough — a
  /// player could walk through an arrow into a pocket they can never
  /// leave, with no fail state to rescue them.
  ///
  /// So this asserts the stronger property: from **every** cell the player
  /// could possibly reach, the destination is still reachable. If that
  /// holds, no sequence of legal moves can ever strand them.
  bool isAlwaysEscapable() {
    for (final cell in reachableFrom(maze.start)) {
      if (cell == maze.destination) continue;
      if (!reachableFrom(cell).contains(maze.destination)) return false;
    }
    return true;
  }

  MazeMovementRules copyWith({
    Map<MazeCoord, MazeDirection>? oneWayArrows,
    Set<MazeCoord>? sandCells,
    TeleportNetwork? teleports,
    ObstacleField? obstacles,
    ShiftingWalls? shiftingWalls,
    bool? useTeleportCooldown,
    bool? respectObstacles,
  }) {
    return MazeMovementRules(
      maze: maze,
      doors: doors,
      teleports: teleports ?? this.teleports,
      obstacles: obstacles ?? this.obstacles,
      shiftingWalls: shiftingWalls ?? this.shiftingWalls,
      oneWayArrows: oneWayArrows ?? this.oneWayArrows,
      sandCells: sandCells ?? this.sandCells,
      useTeleportCooldown: useTeleportCooldown ?? this.useTeleportCooldown,
      respectObstacles: respectObstacles ?? this.respectObstacles,
    );
  }

  // ---- Deterministic placement ----

  /// Places up to [tileCount] arrow tiles along [solutionPath], pointing
  /// the way the solution runs, keeping only the ones that leave the level
  /// escapable from everywhere.
  ///
  /// No RNG: candidates are taken at even intervals along the path, so a
  /// level's arrows are fixed by its seed. Every candidate is accepted
  /// only after [isAlwaysEscapable] passes with it applied, which is what
  /// stops an arrow from sealing the player into a cul-de-sac.
  static Map<MazeCoord, MazeDirection> placeOneWays({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required int tileCount,
    DoorsAndKeys? doors,
    Set<MazeCoord> sandCells = const {},
    Set<MazeCoord> avoid = const {},
  }) {
    if (tileCount < 1 || solutionPath.length < 5) return const {};

    final accepted = <MazeCoord, MazeDirection>{};
    final step = (solutionPath.length / (tileCount + 1)).floor().clamp(1, solutionPath.length);

    for (var i = 1; i <= tileCount; i++) {
      final index = step * i;
      if (index < 1 || index >= solutionPath.length - 1) continue;
      final cell = solutionPath[index];
      if (cell == maze.start || cell == maze.destination) continue;
      if (accepted.containsKey(cell) || avoid.contains(cell)) continue;
      if (sandCells.contains(cell)) continue;
      if (maze.starCoords.contains(cell)) continue;

      final direction = _directionBetween(cell, solutionPath[index + 1]);
      if (direction == null) continue;

      final trial = {...accepted, cell: direction};
      final rules = MazeMovementRules(
        maze: maze,
        doors: doors,
        oneWayArrows: trial,
        sandCells: sandCells,
      );
      if (!rules.isAlwaysEscapable()) continue;

      accepted[cell] = direction;
    }
    return accepted;
  }

  /// Places up to [patchCount] runs of sand, each at most [patchLength]
  /// cells, along [solutionPath] — and again only keeps a run if the level
  /// stays escapable from everywhere with it in place, since a slide can
  /// fling the player somewhere a plain step never would.
  static Set<MazeCoord> placeSand({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required int patchCount,
    required int patchLength,
    DoorsAndKeys? doors,
    Map<MazeCoord, MazeDirection> oneWayArrows = const {},
    Set<MazeCoord> avoid = const {},
  }) {
    if (patchCount < 1 || patchLength < 1 || solutionPath.length < 5) return const {};

    final accepted = <MazeCoord>{};
    final step = (solutionPath.length / (patchCount + 1)).floor().clamp(1, solutionPath.length);

    for (var i = 1; i <= patchCount; i++) {
      final start = step * i;
      final run = <MazeCoord>[];
      for (var j = 0; j < patchLength; j++) {
        final index = start + j;
        if (index < 1 || index >= solutionPath.length - 1) break;
        final cell = solutionPath[index];
        if (cell == maze.start || cell == maze.destination) continue;
        if (accepted.contains(cell) || avoid.contains(cell)) continue;
        if (oneWayArrows.containsKey(cell)) continue;
        // Keys and stars on sand would be unreachable — you'd slide
        // straight over them without being able to stop.
        if (maze.starCoords.contains(cell)) continue;
        if (doors?.keys.containsKey(cell) ?? false) continue;
        run.add(cell);
      }
      if (run.isEmpty) continue;

      final trial = {...accepted, ...run};
      final rules = MazeMovementRules(
        maze: maze,
        doors: doors,
        oneWayArrows: oneWayArrows,
        sandCells: trial,
      );
      if (!rules.isAlwaysEscapable()) continue;

      accepted.addAll(run);
    }
    return accepted;
  }

  /// A7 — picks up to [toggleCount] passages along [solutionPath] that may
  /// safely shift, and proves the choice across **every** combination of
  /// open/closed states.
  ///
  /// That exhaustive check is the point. A toggle that looks harmless in
  /// isolation can still trap the player once a *second* toggle is also
  /// shut, or once an arrow tile is involved, so checking only the
  /// all-open and all-closed extremes would not be enough. With `n`
  /// toggles there are `2^n` states, and `n` stays small (1-2), so the
  /// enumeration is cheap.
  ///
  /// Deterministic: candidates are taken from the path in order, no RNG.
  static ShiftingWalls placeShiftingWalls({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required int toggleCount,
    required Duration interval,
    required Duration warningLead,
    DoorsAndKeys? doors,
    TeleportNetwork? teleports,
    Map<MazeCoord, MazeDirection> oneWayArrows = const {},
    Set<MazeCoord> sandCells = const {},
    Set<MazeCoord> avoid = const {},
  }) {
    if (toggleCount < 1 || solutionPath.length < 4) {
      return ShiftingWalls.none();
    }

    final accepted = <MazePassageEdge>[];
    final step = (solutionPath.length / (toggleCount + 1)).floor().clamp(1, solutionPath.length);

    for (var i = 1; i <= toggleCount; i++) {
      final index = step * i;
      if (index < 1 || index >= solutionPath.length) continue;

      final before = solutionPath[index - 1];
      final after = solutionPath[index];
      if (avoid.contains(before) || avoid.contains(after)) continue;
      final direction = _directionBetween(before, after);
      if (direction == null) continue;

      final candidate = MazePassageEdge(before, direction);
      if (accepted.contains(candidate)) continue;
      // Never put a toggle on a passage a locked door already owns, or the
      // two mechanics would fight over the same gap.
      if (doors?.doors.any((d) => d.edge == candidate) ?? false) continue;

      final trial = [...accepted, candidate];
      final safeInEveryState = ShiftingWalls.allStates(trial).every((closed) {
        final rules = MazeMovementRules(
          maze: maze,
          doors: doors,
          teleports: teleports,
          shiftingWalls: ShiftingWalls.frozen(edges: trial, closed: closed),
          oneWayArrows: oneWayArrows,
          sandCells: sandCells,
        );
        return rules.isAlwaysEscapable();
      });
      if (!safeInEveryState) continue;

      accepted.add(candidate);
    }

    if (accepted.isEmpty) return ShiftingWalls.none();
    return ShiftingWalls(
      edges: accepted,
      interval: interval,
      warningLead: warningLead,
    );
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
