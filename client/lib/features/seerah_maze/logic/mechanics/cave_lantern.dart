import 'dart:math' as math;

import '../../models/maze_cell.dart';
import '../../models/maze_mechanics.dart';

/// A2 — dark cave mode's lantern, as pure logic with no `dart:ui`
/// dependency.
///
/// Owns three things: the lit radius (base, plus a temporary widening from
/// a light-orb pickup, plus a gentle flicker), where the light orbs sit,
/// and which of them have been collected.
///
/// The flicker is a pure function of elapsed time rather than a random
/// walk, so the same playthrough always looks the same and the radius is
/// directly assertable in tests. Orb placement is likewise fully derived
/// from the level's solution path — no RNG at all — so it's deterministic
/// by construction rather than by seeding.
///
/// Like fog, none of this changes which moves are legal, so it cannot
/// affect solvability: orbs are a help, never a gate.
class CaveLantern {
  CaveLantern({required this.config, required Set<MazeCoord> orbCells})
      : _remainingOrbs = Set.of(orbCells);

  final CaveConfig config;

  final Set<MazeCoord> _remainingOrbs;
  Duration _boostRemaining = Duration.zero;

  /// Orbs still waiting to be picked up, for the painter and for tests.
  Set<MazeCoord> get remainingOrbs => Set.unmodifiable(_remainingOrbs);

  /// Whether a pickup's widened radius is currently active.
  bool get isBoosted => _boostRemaining > Duration.zero;

  Duration get boostRemaining => _boostRemaining;

  /// Picks up an orb if one sits on [coord], restarting the boost window.
  /// Returns whether anything was collected, so the caller can fire a
  /// sound/haptic only on a real pickup.
  bool collectAt(MazeCoord coord) {
    if (!_remainingOrbs.remove(coord)) return false;
    // Restart rather than accumulate: walking over two orbs back-to-back
    // gives a fresh full window, not a stacking one that could keep the
    // cave lit for the whole level.
    _boostRemaining = config.boostDuration;
    return true;
  }

  /// Advances the boost countdown. Driven by the same game tick that
  /// advances the level timer, so it pauses exactly when the game does.
  void tick(Duration delta) {
    if (_boostRemaining == Duration.zero) return;
    final next = _boostRemaining - delta;
    _boostRemaining = next.isNegative ? Duration.zero : next;
  }

  /// The lit radius in cells at [elapsed] into the level — the boosted or
  /// base radius, breathing by [CaveConfig.flickerAmplitude].
  double radiusAt(Duration elapsed) {
    final base = isBoosted ? config.boostedLanternRadius : config.lanternRadius;
    if (config.flickerAmplitude == 0) return base;
    final phase = elapsed.inMilliseconds / _flickerPeriod.inMilliseconds * 2 * math.pi;
    // Two offset sine terms so the flicker reads as an uneven flame rather
    // than an obviously periodic pulse.
    final wobble = 0.65 * math.sin(phase) + 0.35 * math.sin(phase * 2.7);
    return base * (1 + config.flickerAmplitude * wobble);
  }

  static const _flickerPeriod = Duration(milliseconds: 1700);

  /// Places light orbs along [solutionPath] every [spacing] steps, so they
  /// fall naturally on the route rather than down side branches — a cave
  /// lantern should reward walking the tunnel, not detouring away from it
  /// (that's what the collectible stars at dead ends are already for).
  ///
  /// Skips the start and destination, plus anything in [exclude] (the
  /// star cells), so an orb never shares a cell with another collectible.
  static Set<MazeCoord> placeOrbs({
    required List<MazeCoord> solutionPath,
    required int spacing,
    Set<MazeCoord> exclude = const {},
  }) {
    if (solutionPath.length < 3 || spacing < 1) return const {};
    final orbs = <MazeCoord>{};
    for (var i = spacing; i < solutionPath.length - 1; i += spacing) {
      final coord = solutionPath[i];
      if (exclude.contains(coord)) continue;
      orbs.add(coord);
    }
    return orbs;
  }
}
