import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../logic/environment/ambient_particle_field.dart';
import '../models/maze_environment.dart';
import '../models/maze_intro_scene.dart';

/// B3 — the short procedural scene behind a level's story card: a sun
/// rising to rest, a caravan silhouette crossing and looping, or stars
/// fading in one by one. Reuses the level's own [MazeEnvironmentTheme]
/// colors (B2) rather than a separate palette, so the intro card previews
/// the same atmosphere the level itself will open in.
///
/// [t] is seconds since the scene started — a plain elapsed clock, not a
/// looping 0..1 fraction, so "rise to rest" (sunRising) and "fade in one
/// by one" (starsAppearing) can have a clear beginning rather than
/// restarting every cycle. [reduceMotion] renders the scene's settled end
/// state directly, with no animation at all.
class IntroScenePainter extends CustomPainter {
  IntroScenePainter({
    required this.motif,
    required this.theme,
    required this.t,
    required this.reduceMotion,
  }) : _stars = motif == MazeIntroSceneMotif.starsAppearing
            ? AmbientParticleField(type: MazeAmbientParticleType.stars, seed: 1, particleCount: 10)
            : null;

  final MazeIntroSceneMotif motif;
  final MazeEnvironmentTheme theme;
  final double t;
  final bool reduceMotion;

  final AmbientParticleField? _stars;

  static const double _riseDuration = 2.2;
  static const double _starRevealDuration = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    switch (motif) {
      case MazeIntroSceneMotif.sunRising:
        _paintSunRising(canvas, size);
      case MazeIntroSceneMotif.caravanCrossing:
        _paintCaravanCrossing(canvas, size);
      case MazeIntroSceneMotif.starsAppearing:
        _paintStarsAppearing(canvas, size);
    }
  }

  void _paintSunRising(Canvas canvas, Size size) {
    final horizonY = size.height * 0.68;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = theme.glowTint.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );

    // 0 at the very bottom (below the horizon), 1 at rest just above it —
    // reduce-motion skips straight to the resting frame.
    final riseProgress = reduceMotion ? 1.0 : (t / _riseDuration).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(riseProgress);
    final restY = horizonY - size.height * 0.28;
    final startY = horizonY + size.height * 0.25;
    final sunY = startY + (restY - startY) * eased;
    final sunX = size.width * 0.5;
    final radius = size.height * 0.16;

    // A gentle idle bob once risen, so it doesn't look frozen even at rest.
    final bob =
        reduceMotion ? 0.0 : math.sin((t - _riseDuration).clamp(0, double.infinity) * 0.6) * 2;
    final center = Offset(sunX, sunY + bob);

    canvas.drawCircle(
      center,
      radius * 1.8,
      Paint()
        ..shader = ui.Gradient.radial(center, radius * 1.8, [
          theme.glowTint.withValues(alpha: 0.35 * eased),
          theme.glowTint.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(center, radius, Paint()..color = theme.glowTint.withValues(alpha: eased));
  }

  void _paintCaravanCrossing(Canvas canvas, Size size) {
    final groundY = size.height * 0.78;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = theme.wallTint.withValues(alpha: 0.3)
        ..strokeWidth = 1.5,
    );

    const cycleSeconds = 7.0;
    final progress = reduceMotion ? 0.4 : ((t % cycleSeconds) / cycleSeconds);
    // Travels from off the left edge to off the right edge, so it's
    // always either visible mid-crossing or just about to enter/exit —
    // never a hard pop.
    final x = -size.width * 0.15 + progress * size.width * 1.3;

    final bodyPaint = Paint()..color = theme.wallTint.withValues(alpha: 0.85);
    final legPaint = Paint()
      ..color = theme.wallTint.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1, size.height * 0.02)
      ..strokeCap = StrokeCap.round;
    final bob = reduceMotion ? 0.0 : math.sin(t * 6) * size.height * 0.01;
    final bodyY = groundY - size.height * 0.14 + bob;
    final w = size.height * 0.22;
    final h = size.height * 0.12;

    final body = Path()
      ..moveTo(x - w, bodyY)
      ..quadraticBezierTo(x - w * 0.7, bodyY - h * 1.6, x - w * 0.15, bodyY - h * 0.5)
      ..quadraticBezierTo(x + w * 0.2, bodyY - h * 1.7, x + w * 0.7, bodyY - h * 0.4)
      ..lineTo(x + w * 0.8, bodyY - h * 1.9)
      ..lineTo(x + w, bodyY - h * 1.9)
      ..lineTo(x + w * 0.95, bodyY - h * 0.3)
      ..lineTo(x + w, bodyY)
      ..close();
    canvas.drawPath(body, bodyPaint);
    for (final dx in [-w * 0.6, -w * 0.1, w * 0.4, w * 0.75]) {
      canvas.drawLine(Offset(x + dx, bodyY), Offset(x + dx, bodyY + h * 0.8), legPaint);
    }
  }

  void _paintStarsAppearing(Canvas canvas, Size size) {
    final stars = _stars;
    if (stars == null) return;
    final revealElapsed = reduceMotion ? _starRevealDuration : t;
    final allParticles = stars.particlesAt(revealElapsed);

    for (var i = 0; i < allParticles.length; i++) {
      // Staggered reveal: each star's own fade-in starts a little after
      // the previous one's, so they visibly appear one-by-one rather
      // than all fading in together.
      final revealAt = i / allParticles.length * _starRevealDuration * 0.7;
      final revealProgress = ((revealElapsed - revealAt) / 0.5).clamp(0.0, 1.0).toDouble();
      if (revealProgress <= 0) continue;
      final particle = allParticles[i];
      final center = Offset(particle.position.x * size.width, particle.position.y * size.height);
      canvas.drawCircle(
        center,
        particle.size,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: particle.opacity.clamp(0.0, 1.0) * revealProgress),
      );
    }
  }

  @override
  bool shouldRepaint(covariant IntroScenePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.motif != motif || oldDelegate.reduceMotion != reduceMotion;
}
