import '../../models/maze_cell.dart';
import '../../models/maze_direction.dart';
import '../../models/maze_mechanics.dart';
import '../maze_generator.dart';

/// A6 — a caravan patrolling one straight corridor segment, back and
/// forth, forever.
///
/// Its position is a **pure function of elapsed time**: no internal
/// stepping state, no RNG. That's what makes a playthrough reproducible
/// and the position directly assertable in a test, and it's also why
/// pausing works for free — the caravan simply stops being asked where it
/// is, rather than needing to be told to hold still.
class CaravanRoute {
  CaravanRoute({required List<MazeCoord> segment, required this.cycle})
      : assert(segment.length >= 2, 'a patrol needs somewhere to walk'),
        segment = List.unmodifiable(segment);

  /// The straight run of cells patrolled, in order.
  final List<MazeCoord> segment;

  /// How long one full there-and-back circuit takes.
  final Duration cycle;

  /// Where the caravan is at [elapsed] into the level.
  MazeCoord positionAt(Duration elapsed) => segment[_indexAt(elapsed)];

  int _indexAt(Duration elapsed) {
    final span = segment.length - 1;
    // A full circuit walks out and back, so it's 2*span steps long.
    final totalSteps = span * 2;
    final stepMicros = cycle.inMicroseconds / totalSteps;
    if (stepMicros <= 0) return 0;
    // Negative elapsed can't happen from the game, but clamping keeps the
    // modulo below well-defined for a caller passing something odd.
    final micros = elapsed.inMicroseconds < 0 ? 0 : elapsed.inMicroseconds;
    final step = (micros / stepMicros).floor() % totalSteps;
    return step <= span ? step : totalSteps - step;
  }

  /// Which way the caravan is facing at [elapsed] — for the sprite, so the
  /// camel doesn't walk backwards on the return leg.
  bool isForwardAt(Duration elapsed) {
    final span = segment.length - 1;
    final totalSteps = span * 2;
    final stepMicros = cycle.inMicroseconds / totalSteps;
    if (stepMicros <= 0) return true;
    final micros = elapsed.inMicroseconds < 0 ? 0 : elapsed.inMicroseconds;
    return (micros / stepMicros).floor() % totalSteps <= span;
  }
}

/// A6 — the sandstorm: on a fixed cycle, one corridor cell is blocked for
/// a few seconds, with a warning shown the second before it closes.
///
/// Which cell, and when, are both pure functions of elapsed time and the
/// candidate list (itself seed-derived), so the whole schedule is
/// reproducible. Because every closure always clears again, a sandstorm
/// can only ever *delay* the player — it can't make a level unsolvable,
/// which is why the pathfinder and the solvability checks ignore it.
class SandstormSchedule {
  SandstormSchedule({
    required List<MazeCoord> candidates,
    required this.period,
    required this.blockedDuration,
    required this.warningLead,
  })  : assert(period > blockedDuration + warningLead, 'the storm must have a clear gap'),
        candidates = List.unmodifiable(candidates);

  /// Cells the storm rotates between, in a fixed order.
  final List<MazeCoord> candidates;

  /// How often the storm strikes.
  final Duration period;

  /// How long a cell stays blocked once the storm closes it.
  final Duration blockedDuration;

  /// How long before closing the warning appears.
  final Duration warningLead;

  bool get isEmpty => candidates.isEmpty;

  /// Which cell this cycle targets. Rotates through the candidates so the
  /// storm doesn't hammer the same spot every time.
  MazeCoord _targetForCycle(int cycleIndex) => candidates[cycleIndex % candidates.length];

  /// The cell currently blocked, or null if the storm is between strikes.
  ///
  /// Each cycle runs: clear ... warning ... blocked ... (next cycle). The
  /// blocked window sits at the end of the cycle so the warning that
  /// precedes it belongs to the same cycle index, which keeps the two
  /// consistent without any shared state.
  MazeCoord? blockedAt(Duration elapsed) {
    final (cycleIndex, intoCycle) = _cyclePosition(elapsed);
    final blockedStart = period - blockedDuration;
    if (intoCycle < blockedStart) return null;
    return _targetForCycle(cycleIndex);
  }

  /// The cell about to be blocked, during its warning window only.
  MazeCoord? warningAt(Duration elapsed) {
    final (cycleIndex, intoCycle) = _cyclePosition(elapsed);
    final blockedStart = period - blockedDuration;
    final warningStart = blockedStart - warningLead;
    if (intoCycle < warningStart || intoCycle >= blockedStart) return null;
    return _targetForCycle(cycleIndex);
  }

  (int, Duration) _cyclePosition(Duration elapsed) {
    final micros = elapsed.inMicroseconds < 0 ? 0 : elapsed.inMicroseconds;
    final periodMicros = period.inMicroseconds;
    return (
      micros ~/ periodMicros,
      Duration(microseconds: micros % periodMicros),
    );
  }
}

/// A6 — all the moving obstacles on one level, driven by a single clock.
///
/// [elapsed] only ever advances through [tick], which the game screen
/// drives from the same timer as the level clock. So when the game pauses
/// or the app is backgrounded, the obstacles freeze along with it — the
/// spec's "obstacles pause when the game is paused or backgrounded" falls
/// out of that rather than needing separate handling.
class ObstacleField {
  ObstacleField({
    List<CaravanRoute> caravans = const [],
    this.sandstorm,
  }) : caravans = List.unmodifiable(caravans);

  factory ObstacleField.none() => ObstacleField();

  final List<CaravanRoute> caravans;
  final SandstormSchedule? sandstorm;

  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;

  bool get isEmpty => caravans.isEmpty && (sandstorm?.isEmpty ?? true);

  void tick(Duration delta) => _elapsed += delta;

  void reset() => _elapsed = Duration.zero;

  /// Where every caravan is right now.
  Set<MazeCoord> get caravanCells => {
        for (final caravan in caravans) caravan.positionAt(_elapsed),
      };

  /// The cell the sandstorm has closed right now, if any.
  MazeCoord? get blockedCell => sandstorm?.blockedAt(_elapsed);

  /// The cell the sandstorm is about to close, during the warning only.
  MazeCoord? get warningCell => sandstorm?.warningAt(_elapsed);

  /// Whether the player is currently refused entry to [coord].
  bool blocks(MazeCoord coord) => blockedCell == coord;

  /// Whether a caravan is standing on [coord] right now.
  bool hasCaravanAt(MazeCoord coord) => caravanCells.contains(coord);

  // ---- Placement ----

  /// Finds a straight run of at least [minLength] connected cells along
  /// [solutionPath] for a caravan to patrol.
  ///
  /// Deterministic: scans the path in order and takes the first run long
  /// enough, so a level's caravan route is fixed by its seed. Returns an
  /// empty list when the maze has no straight corridor that long, in which
  /// case the level simply gets no caravan rather than a degenerate one.
  static List<CaravanRoute> placeCaravans({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required int caravanCount,
    required Duration cycle,
    int minLength = 3,
    Set<MazeCoord> reserved = const {},
  }) {
    if (caravanCount < 1 || solutionPath.length < minLength) return const [];

    final routes = <CaravanRoute>[];
    final claimed = <MazeCoord>{};

    var index = 0;
    while (index < solutionPath.length && routes.length < caravanCount) {
      final run = _straightRunAt(solutionPath, index);
      final usable = run
          .where((c) =>
              c != maze.start &&
              c != maze.destination &&
              !reserved.contains(c) &&
              !claimed.contains(c) &&
              !maze.starCoords.contains(c))
          .toList();

      if (usable.length >= minLength) {
        routes.add(CaravanRoute(segment: usable, cycle: cycle));
        claimed.addAll(usable);
        index += run.length;
      } else {
        index += run.isEmpty ? 1 : run.length;
      }
    }
    return routes;
  }

  /// The straight, same-direction run of [path] starting at [from].
  static List<MazeCoord> _straightRunAt(List<MazeCoord> path, int from) {
    if (from >= path.length) return const [];
    if (from == path.length - 1) return [path[from]];

    final run = <MazeCoord>[path[from]];
    final direction = _directionBetween(path[from], path[from + 1]);
    if (direction == null) return run;

    for (var i = from + 1; i < path.length; i++) {
      if (_directionBetween(path[i - 1], path[i]) != direction) break;
      run.add(path[i]);
    }
    return run;
  }

  /// Picks the cells a sandstorm may close: plain corridor cells (exactly
  /// two open sides, so neither a junction nor a dead end) along the
  /// solution path. Blocking a junction would be far harsher, and blocking
  /// a dead end would be pointless.
  static SandstormSchedule? placeSandstorm({
    required MazeGenerationResult maze,
    required List<MazeCoord> solutionPath,
    required SandstormConfig config,
    Set<MazeCoord> reserved = const {},
  }) {
    final candidates = <MazeCoord>[];
    for (final coord in solutionPath) {
      if (coord == maze.start || coord == maze.destination) continue;
      if (reserved.contains(coord) || maze.starCoords.contains(coord)) continue;
      if (maze.cellAt(coord).openDirections.length != 2) continue;
      if (candidates.contains(coord)) continue;
      candidates.add(coord);
      if (candidates.length >= config.maxTargets) break;
    }
    if (candidates.isEmpty) return null;

    return SandstormSchedule(
      candidates: candidates,
      period: config.period,
      blockedDuration: config.blockedDuration,
      warningLead: config.warningLead,
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
