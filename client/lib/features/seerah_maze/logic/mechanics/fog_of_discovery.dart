import 'dart:math' as math;

import '../../models/maze_cell.dart';
import '../../models/maze_mechanics.dart';

/// How a single cell should read under fog.
enum FogVisibility {
  /// Within the player's current light radius — drawn normally.
  lit,

  /// Seen earlier but not currently lit — drawn faintly, so the player
  /// keeps a mental map of where they've already been.
  remembered,

  /// Never been within the light radius — veiled.
  hidden,
}

/// A1 — fog of discovery, as pure logic with no `dart:ui` dependency.
///
/// Owns the one piece of state fog actually needs: the set of cells the
/// player has already lit at some point ("remembered"). Visibility itself
/// is derived, never stored, so it can't drift out of sync with the
/// player's position.
///
/// Deliberately not seeded/random: fog placement is a pure function of
/// where the player has walked, so it's reproducible by construction and
/// can never make a level unsolvable (it changes only what's drawn, never
/// which moves are legal — so the solvability validator doesn't need to
/// model it at all).
class FogOfDiscovery {
  FogOfDiscovery({required this.config});

  final FogConfig config;

  final Set<MazeCoord> _remembered = {};

  /// Every cell the player has lit so far, for painters and for tests.
  Set<MazeCoord> get rememberedCells => Set.unmodifiable(_remembered);

  /// Records the player standing at [playerPosition], lighting (and
  /// therefore permanently remembering) every cell inside the visibility
  /// radius. Call once per move, and once at level start for the start
  /// cell. Returns the cells newly revealed by this step, which the fog
  /// layer fades in rather than popping.
  Set<MazeCoord> reveal({
    required MazeCoord playerPosition,
    required int mazeSize,
    double? radiusOverride,
  }) {
    final radius = radiusOverride ?? config.visibilityRadius;
    final newlyRevealed = <MazeCoord>{};
    final span = radius.ceil();
    for (var row = playerPosition.row - span; row <= playerPosition.row + span; row++) {
      for (var col = playerPosition.col - span; col <= playerPosition.col + span; col++) {
        if (row < 0 || col < 0 || row >= mazeSize || col >= mazeSize) continue;
        final coord = MazeCoord(row, col);
        if (_distance(coord, playerPosition) > radius) continue;
        if (_remembered.add(coord)) newlyRevealed.add(coord);
      }
    }
    return newlyRevealed;
  }

  /// How [coord] should be drawn with the player at [playerPosition].
  FogVisibility visibilityOf(
    MazeCoord coord, {
    required MazeCoord playerPosition,
    double? radiusOverride,
  }) {
    final radius = radiusOverride ?? config.visibilityRadius;
    if (_distance(coord, playerPosition) <= radius) return FogVisibility.lit;
    if (_remembered.contains(coord)) return FogVisibility.remembered;
    return FogVisibility.hidden;
  }

  /// The veil strength (0 = clear, 1 = fully hidden) for [visibility],
  /// straight from this level's [FogConfig].
  double veilFor(FogVisibility visibility) => switch (visibility) {
        FogVisibility.lit => 0,
        FogVisibility.remembered => config.rememberedOpacity,
        FogVisibility.hidden => config.hiddenOpacity,
      };

  /// Forgets everything — used when a level restarts, so a replay starts
  /// dark again rather than inheriting the previous run's map.
  void reset() => _remembered.clear();

  static double _distance(MazeCoord a, MazeCoord b) =>
      math.sqrt(math.pow(a.row - b.row, 2) + math.pow(a.col - b.col, 2));
}
