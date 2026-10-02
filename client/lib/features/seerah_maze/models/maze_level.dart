import 'maze_mechanics.dart';

/// What the destination of a level represents, visually — lets the
/// destination painter (added in a later build step) pick an appropriate
/// simple icon/shape per level without binding level data to a concrete
/// Flutter icon or asset ahead of time.
enum MazeDestinationKind { kaaba, town, cave, caravan, house, gathering }

/// Static, structural definition of one Seerah Maze level. Deliberately
/// holds no display text at all — character/destination names and the
/// story/win lines all live in the app's ARB files instead (keyed by this
/// level's `id`; see data/maze_levels.dart's `mazeLevelTextFor`), since
/// they need a live `AppLocalizations` lookup and this model stays a
/// plain compile-time `const` so `kMazeLevels` can keep being one.
class MazeLevel {
  const MazeLevel({
    required this.id,
    required this.gridSize,
    required this.seed,
    required this.extraLoopCount,
    required this.starTimeThreshold,
    required this.destinationKind,
    required this.usesLightMarker,
    this.mechanics = MazeMechanics.none,
  });

  /// 1-based level number; also doubles as its unlock-order position.
  final int id;

  final int gridSize;

  /// Feeds `Random(seed)` in MazeGenerator — same seed always produces the
  /// same maze.
  final int seed;

  /// Extra walls knocked out after the perfect-maze carve, adding loops
  /// (more than one valid route) on later, larger levels.
  final int extraLoopCount;

  /// Finishing at or under this duration contributes a star — see
  /// GameController.rating.
  final Duration starTimeThreshold;

  final MazeDestinationKind destinationKind;

  /// True only for levels where the traveler is the Prophet Muhammad ﷺ
  /// (levels 5 and 8) — per the "no human figure for the Prophet ﷺ" rule,
  /// the game draws a glowing light/star marker instead of the usual
  /// silhouette avatar whenever this is true.
  final bool usesLightMarker;

  /// Which Phase 2 mechanics this level opts into, and with what
  /// parameters. Defaults to [MazeMechanics.none], which reproduces the
  /// original Phase 1 behavior exactly.
  final MazeMechanics mechanics;
}
