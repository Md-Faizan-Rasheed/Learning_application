import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One simple physics-free (gravity only) particle. Mutated in place every
/// tick by the board widget's animation loop rather than reallocated, to
/// keep the per-frame cost near zero even with dozens alive at once.
class MazeParticle {
  MazeParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required double life,
  })  : life = life,
        maxLife = life;

  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  double life;
  final double maxLife;

  bool get isAlive => life > 0;

  /// 0 (just spawned) .. 1 (about to die).
  double get progress => (1 - (life / maxLife)).clamp(0, 1);

  void update(double dtSeconds) {
    life -= dtSeconds;
    position += velocity * dtSeconds;
    velocity += Offset(0, 260 * dtSeconds); // gentle gravity, pulls the burst down
  }
}

/// Renders whatever particles are currently alive — used for both the
/// small star-pickup burst (step 3) and the larger win-moment burst (a
/// later build step), just with a different spawn count/spread.
class ParticlePainter extends CustomPainter {
  const ParticlePainter({required this.particles});

  final List<MazeParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (!particle.isAlive) continue;
      final alpha = 1 - particle.progress;
      canvas.drawCircle(
        particle.position,
        particle.size * (1 - particle.progress * 0.4),
        Paint()..color = particle.color.withValues(alpha: alpha.clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

/// A small radial burst spawned at [origin] — the caller owns the returned
/// list (appends it to whatever's already alive, update()s and prunes
/// dead ones each tick).
List<MazeParticle> spawnMazeParticleBurst({
  required Offset origin,
  required int count,
  required List<Color> colors,
  required math.Random random,
  double speed = 140,
  double size = 4,
  double minLifeSeconds = 0.5,
  double lifeSpreadSeconds = 0.3,
}) {
  return List.generate(count, (_) {
    final angle = random.nextDouble() * 2 * math.pi;
    final magnitude = speed * (0.6 + random.nextDouble() * 0.8);
    return MazeParticle(
      position: origin,
      velocity: Offset(math.cos(angle), math.sin(angle)) * magnitude,
      color: colors[random.nextInt(colors.length)],
      size: size * (0.7 + random.nextDouble() * 0.6),
      life: minLifeSeconds + random.nextDouble() * lifeSpreadSeconds,
    );
  });
}
