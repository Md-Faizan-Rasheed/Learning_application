import 'dart:math' as math;

import '../../models/maze_environment.dart';

/// One ambient particle's fractional (0..1, 0..1) position within the
/// background and its current opacity, for the painter to scale onto the
/// actual canvas size.
class AmbientParticle {
  const AmbientParticle({required this.position, required this.opacity, required this.size});

  final math.Point<double> position;
  final double opacity;
  final double size;

  @override
  bool operator ==(Object other) =>
      other is AmbientParticle &&
      other.position == position &&
      other.opacity == opacity &&
      other.size == size;

  @override
  int get hashCode => Object.hash(position, opacity, size);
}

/// B2 — the ambient dust/firefly/star field drifting behind a level's
/// board, as pure math with no `dart:ui` dependency.
///
/// Every particle's position is a closed-form function of elapsed time
/// and its own fixed per-particle phase (seeded once from the level id,
/// never re-rolled), so the field is fully deterministic and directly
/// assertable — and "reduce motion" is simply a caller choosing not to
/// advance the clock, not a separate code path here.
///
/// Kept deliberately small ([particleCount] caps at a modest constant)
/// since this runs behind every level for the level's whole lifetime,
/// unlike the one-shot mechanic particle bursts.
class AmbientParticleField {
  AmbientParticleField({required this.type, required int seed, this.particleCount = 14})
      : _phases = List.generate(
          particleCount,
          (i) => _Phase.seeded(seed * 97 + i, i, particleCount),
        );

  final MazeAmbientParticleType type;
  final int particleCount;
  final List<_Phase> _phases;

  /// Every particle's state at [elapsedSeconds] into the level.
  List<AmbientParticle> particlesAt(double elapsedSeconds) =>
      [for (final phase in _phases) _particleAt(phase, elapsedSeconds)];

  AmbientParticle _particleAt(_Phase phase, double t) {
    switch (type) {
      case MazeAmbientParticleType.dust:
        // Slow horizontal drift with a gentle vertical bob, wrapping
        // around the width so it reads as an endless light haze.
        final x = (phase.baseX + t * 0.015 * phase.speedSign) % 1.0;
        final y = phase.baseY + math.sin(t * 0.3 + phase.phase) * 0.02;
        final opacity = 0.25 + 0.2 * (0.5 + 0.5 * math.sin(t * 0.5 + phase.phase));
        return AmbientParticle(
          position: math.Point(x < 0 ? x + 1 : x, y.clamp(0.0, 1.0)),
          opacity: opacity,
          size: phase.size,
        );

      case MazeAmbientParticleType.fireflies:
        // A small Lissajous-style meander — looks like aimless wandering
        // but is a pure, reproducible function of t.
        final x = phase.baseX + math.sin(t * 0.25 + phase.phase) * 0.08;
        final y = phase.baseY + math.cos(t * 0.2 + phase.phase * 1.3) * 0.08;
        final opacity = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(t * 1.1 + phase.phase * 2));
        return AmbientParticle(
          position: math.Point(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)),
          opacity: opacity,
          size: phase.size,
        );

      case MazeAmbientParticleType.stars:
        // Fixed position, just a gentle twinkle — stars don't drift.
        final opacity = 0.4 + 0.5 * (0.5 + 0.5 * math.sin(t * 0.8 + phase.phase * 3));
        return AmbientParticle(
          position: math.Point(phase.baseX, phase.baseY),
          opacity: opacity,
          size: phase.size,
        );
    }
  }
}

/// A particle's fixed identity — everything that stays constant across
/// the particle's lifetime, derived once from a deterministic seed.
class _Phase {
  const _Phase({
    required this.baseX,
    required this.baseY,
    required this.phase,
    required this.speedSign,
    required this.size,
  });

  final double baseX;
  final double baseY;
  final double phase;
  final double speedSign;
  final double size;

  factory _Phase.seeded(int seed, int index, int total) {
    final random = math.Random(seed);
    return _Phase(
      // Spread roughly evenly across columns with a little jitter, rather
      // than fully random (which clumps for small counts).
      baseX: ((index + random.nextDouble()) / total).clamp(0.0, 1.0),
      baseY: random.nextDouble(),
      phase: random.nextDouble() * 2 * math.pi,
      speedSign: random.nextBool() ? 1.0 : -1.0,
      size: 1.5 + random.nextDouble() * 2.0,
    );
  }
}
