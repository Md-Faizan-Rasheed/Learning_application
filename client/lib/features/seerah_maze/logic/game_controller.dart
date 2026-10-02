import '../constants/maze_constants.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import '../models/maze_door.dart';
import '../models/maze_level.dart';
import 'maze_generator.dart';
import 'maze_solver.dart';
import 'mechanics/doors_and_keys.dart';
import 'mechanics/movement_rules.dart';

/// 1 star: finished at all. 2 stars: finished under the level's time
/// threshold OR collected every star. 3 stars: both. See
/// [GameController.rating] — only meaningful once [GameController.isWon].
enum MazeRating { one, two, three }

/// Pure Dart gameplay state machine for one play-through of a level:
/// player position, elapsed time, collected stars, hints used, and win
/// detection. Holds no Flutter/UI dependency so it's directly unit
/// testable; a UI layer (added in a later build step) drives it via
/// [move]/[stepToward]/[useHint]/[tick] and reads [playerPosition] etc. to
/// render.
class GameController {
  GameController({
    required this.maze,
    required this.level,
    DoorsAndKeys? doors,
    MazeMovementRules? movement,
    this.factScrollCell,
  })  : playerPosition = maze.start,
        collectedStars = <MazeCoord>{},
        hintsUsed = 0,
        doors = doors ?? DoorsAndKeys.none(),
        movement = movement ?? MazeMovementRules(maze: maze, doors: doors),
        _elapsed = Duration.zero,
        _paused = false {
    // The trail starts where the player does, so a pushback on the very
    // first move has somewhere to step back to.
    _recentCells.add(maze.start);
  }

  final MazeGenerationResult maze;
  final MazeLevel level;

  /// A3 — this level's locked doors and their keys. Empty (and therefore
  /// inert) on every level that doesn't use the mechanic.
  final DoorsAndKeys doors;

  /// A4 — the movement model: which moves are legal and where they land.
  /// On a level with no movement mechanics this is the plain open-wall
  /// rule, so behavior matches Phase 1 exactly.
  final MazeMovementRules movement;

  /// The cells the most recent move carried the player across, when sand
  /// slid them more than one cell — for the board's slide animation. Empty
  /// after an ordinary single-cell step.
  List<MazeCoord> lastSlidePath = const [];

  /// A5 — the tent the most recent move jumped from, or null if it wasn't
  /// a teleport. Drives the board's fade/scale jump.
  MazeCoord? lastTeleportFrom;

  /// A6 — true when the most recent move ended in a caravan nudging the
  /// player back. Never a failure: the only cost is the walk back.
  bool lastMoveHitCaravan = false;

  /// B4 — where this level's one collectible fact scroll sits, or null if
  /// this level has none (the generator found no free dead end).
  final MazeCoord? factScrollCell;

  /// Whether [factScrollCell] has been walked onto yet. Stays false
  /// forever if [factScrollCell] is null.
  bool factCollected = false;

  /// True only on the move that actually collected the scroll — the
  /// caller's cue to fire feedback once, not on every move afterward.
  bool lastMoveCollectedFact = false;

  /// The cells the player has recently stood on, oldest first. Only used
  /// to nudge them back along ground they've already walked, so a caravan
  /// pushback can never shove them through a wall.
  final List<MazeCoord> _recentCells = [];

  MazeCoord playerPosition;
  final Set<MazeCoord> collectedStars;
  int hintsUsed;

  /// The key kinds picked up so far, for the HUD's inventory.
  Set<MazeKeyKind> get heldKeys => doors.heldKeys;

  Duration _elapsed;
  bool _paused;

  bool get isWon => playerPosition == maze.destination;
  Duration get elapsed => _elapsed;
  bool get isPaused => _paused;

  int get hintsRemaining => MazeConstants.maxHintsPerLevel - hintsUsed;

  void pause() => _paused = true;
  void resume() => _paused = false;

  /// Advances the informational timer by [delta] — a no-op while paused or
  /// after winning, so the clock stops counting the moment the maze is
  /// solved.
  void tick(Duration delta) {
    if (_paused || isWon) return;
    _elapsed += delta;
    // A5/A6 — the tent cooldown and the moving obstacles run on this same
    // clock, so they pause when the game does rather than drifting on in
    // the background.
    movement.teleports?.tick(delta);
    movement.obstacles?.tick(delta);
    movement.shiftingWalls?.tick(delta);
  }

  /// Attempts one step in [direction]. Returns true if the player actually
  /// moved (the caller animates it); false if that wall is closed, or a
  /// locked door blocks it, in which case the caller triggers bump
  /// feedback instead. Walking onto a star or key cell collects it
  /// automatically.
  bool move(MazeDirection direction) {
    if (isWon) return false;
    // A3/A4 — walls, locked doors and arrow tiles all come back as "this
    // move isn't legal", and the caller bumps; sand comes back as a run of
    // several cells rather than one.
    final result = movement.resolveMove(playerPosition, direction);
    if (result == null) return false;

    lastSlidePath = result.isSlide ? result.path : const [];
    lastTeleportFrom = result.teleportedFrom;
    lastMoveHitCaravan = false;
    lastMoveCollectedFact = false;
    if (result.isTeleport) movement.teleports?.startCooldown();
    // Collect along the whole run: the player physically passes over every
    // cell in it, so stopping only at the landing cell would silently eat
    // a collectible they slid across.
    for (final cell in result.path) {
      if (maze.starCoords.contains(cell)) collectedStars.add(cell);
      doors.collectKeyAt(cell);
      if (!factCollected && cell == factScrollCell) {
        factCollected = true;
        lastMoveCollectedFact = true;
      }
      // Sliding across the destination finishes the level, rather than
      // skidding past the goal.
      if (cell == maze.destination) {
        playerPosition = cell;
        return true;
      }
    }
    playerPosition = result.landing;
    _recordVisit(result.landing);

    // A6 — walking into a caravan gently pushes the player back along the
    // way they came. Checked after the move resolves rather than as a
    // movement restriction, because contact is an *event*, not a wall: the
    // level never fails, the player just loses the time.
    if (movement.obstacles?.hasCaravanAt(playerPosition) ?? false) {
      lastMoveHitCaravan = true;
      _pushBack(level.mechanics.caravans?.pushBackCells ?? 2);
    }
    return true;
  }

  void _recordVisit(MazeCoord coord) {
    if (_recentCells.isNotEmpty && _recentCells.last == coord) return;
    _recentCells.add(coord);
    // Only a few steps of history are ever needed for a pushback.
    while (_recentCells.length > 8) {
      _recentCells.removeAt(0);
    }
  }

  /// Steps the player back up to [cells] along their own recent trail.
  /// Using the trail (rather than the opposite of their last direction)
  /// guarantees the destination is somewhere they could legally stand,
  /// even in a corridor that bends.
  void _pushBack(int cells) {
    for (var i = 0; i < cells; i++) {
      // The last entry is where the player is standing now, so the one
      // before it is a step backwards. With no history left (pushed back
      // to the start), they simply stay put.
      if (_recentCells.length < 2) break;
      _recentCells.removeLast();
      playerPosition = _recentCells.last;
    }
  }

  /// Drag-follow control: if [target] is within
  /// [MazeConstants.maxDragFollowDistance] open-passage steps of the
  /// player, advances exactly one step toward it along the shortest path.
  /// No-ops (returns false) for a target that's the player's own cell,
  /// unreachable, or farther than the limit — this is what stops a single
  /// drag from auto-solving the whole maze.
  bool stepToward(MazeSolver solver, MazeCoord target) {
    if (isWon || target == playerPosition) return false;
    final path = solver.shortestPath(
      maze,
      playerPosition,
      target,
      canPass: movement.canPass,
      landingFor: _landingFor,
    );
    if (path == null || path.length - 1 > MazeConstants.maxDragFollowDistance) {
      return false;
    }
    final next = path[1];
    // Match on where each direction *lands*, not on the adjacent cell, so
    // drag-follow works across a sand slide too.
    for (final (direction, landing) in movement.movesFrom(playerPosition)) {
      if (landing == next) return move(direction);
    }
    return false;
  }

  MazeCoord? _landingFor(MazeCoord from, MazeDirection direction) =>
      movement.resolveMove(from, direction)?.landing;

  /// Returns up to [MazeConstants.hintPathLength] cells along the shortest
  /// remaining path to the destination (excluding the player's own cell),
  /// for the caller to highlight. Returns nothing once hints are
  /// exhausted. Does not affect [rating] — only [hintsUsed] (shown in the
  /// win-card stats), per the "no fail state, no penalty" design.
  List<MazeCoord> useHint(MazeSolver solver) {
    if (hintsRemaining <= 0 || isWon) return const [];
    hintsUsed++;
    // Door-aware, so a hint never points through a door the player can't
    // open yet — it routes toward the key instead, which is the actual
    // next thing they need.
    final path = solver.shortestPath(
      maze,
      playerPosition,
      maze.destination,
      canPass: movement.canPass,
      landingFor: _landingFor,
    );
    if (path != null) {
      return path.skip(1).take(MazeConstants.hintPathLength).toList();
    }
    // The destination is currently sealed behind a locked door, so point
    // at the nearest key the player can actually get to.
    final keyTarget = _nearestReachableKey(solver);
    if (keyTarget == null) return const [];
    final toKey = solver.shortestPath(
      maze,
      playerPosition,
      keyTarget,
      canPass: movement.canPass,
      landingFor: _landingFor,
    );
    if (toKey == null) return const [];
    return toKey.skip(1).take(MazeConstants.hintPathLength).toList();
  }

  MazeCoord? _nearestReachableKey(MazeSolver solver) {
    MazeCoord? best;
    var bestDistance = -1;
    for (final coord in doors.remainingKeys.keys) {
      final distance = solver.distance(
        maze,
        playerPosition,
        coord,
        canPass: movement.canPass,
        landingFor: _landingFor,
      );
      if (distance < 0) continue;
      if (bestDistance == -1 || distance < bestDistance) {
        bestDistance = distance;
        best = coord;
      }
    }
    return best;
  }

  /// Only meaningful once [isWon] is true.
  MazeRating get rating {
    final gotAllStars = collectedStars.length >= maze.starCoords.length;
    final underTime = _elapsed <= level.starTimeThreshold;
    if (gotAllStars && underTime) return MazeRating.three;
    if (gotAllStars || underTime) return MazeRating.two;
    return MazeRating.one;
  }
}
