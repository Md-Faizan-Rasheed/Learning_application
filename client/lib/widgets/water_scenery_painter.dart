import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative rocks and reed-grass along the bottom of the Names of Allah
/// pool's water surface — purely atmospheric, never interactive, and kept
/// out of the way of the floating name cards above them. Rocks are fixed;
/// the grass gets a slow, gentle sway driven by [swayPhase] so the whole
/// scene reads as alive rather than a static backdrop painted once.
///
/// Deterministic (a fixed [seed], not ambient `Random()`) so the layout of
/// rocks/grass doesn't re-scatter on every rebuild — only [swayPhase]
/// changes frame to frame. Colors are existing app tokens: rocks blend
/// [AppPalette.ink] (a wet, dark stone tone against the teal water) with a
/// faint [AppPalette.parchment] highlight streak; grass reuses
/// [AppPalette.barkGreen], the one green already sanctioned in this app as
/// an illustration-only accent (see its doc comment in `app_theme.dart`) —
/// no new hex values introduced for this scene.
class WaterSceneryPainter extends CustomPainter {
  const WaterSceneryPainter({required this.swayPhase, this.seed = 11});

  /// 0..2π — advances slowly to gently sway the grass blades.
  final double swayPhase;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    _paintRocks(canvas, size, rng);
    _paintGrassClusters(canvas, size, math.Random(seed + 1));
  }

  void _paintRocks(Canvas canvas, Size size, math.Random rng) {
    final rockCount = 3 + rng.nextInt(2); // 3-4
    for (var i = 0; i < rockCount; i++) {
      final cx = (i + 0.5) / rockCount * size.width + (rng.nextDouble() - 0.5) * size.width * 0.08;
      final cy = size.height * (0.74 + rng.nextDouble() * 0.16);
      final radius = size.shortestSide * (0.05 + rng.nextDouble() * 0.035);
      _drawRock(canvas, Offset(cx, cy), radius, rng);
    }
  }

  void _drawRock(Canvas canvas, Offset center, double radius, math.Random rng) {
    const points = 9;
    final path = Path();
    for (var i = 0; i < points; i++) {
      final angle = i / points * 2 * math.pi;
      final wobble = 0.72 + rng.nextDouble() * 0.36;
      final p = center + Offset(math.cos(angle), math.sin(angle) * 0.62) * radius * wobble;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppPalette.ink.withValues(alpha: 0.42));

    // A soft wet-highlight streak so the rock reads as sitting in water
    // rather than a flat grey blob.
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-radius * 0.28, -radius * 0.32),
        width: radius * 0.7,
        height: radius * 0.32,
      ),
      Paint()..color = AppPalette.parchment.withValues(alpha: 0.16),
    );
  }

  void _paintGrassClusters(Canvas canvas, Size size, math.Random rng) {
    final clusterCount = 4 + rng.nextInt(3); // 4-6
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.barkGreen.withValues(alpha: 0.8);

    for (var c = 0; c < clusterCount; c++) {
      final baseX = (c + 0.5) / clusterCount * size.width + (rng.nextDouble() - 0.5) * size.width * 0.1;
      final baseY = size.height * (0.82 + rng.nextDouble() * 0.13);
      final bladeCount = 3 + rng.nextInt(3);
      for (var b = 0; b < bladeCount; b++) {
        final restLean = (rng.nextDouble() - 0.5) * 0.7;
        final sway = math.sin(swayPhase + c * 1.3 + b * 0.9) * 0.22;
        final lean = restLean + sway;
        final height = size.shortestSide * (0.09 + rng.nextDouble() * 0.05);
        final base = Offset(baseX + (b - bladeCount / 2) * 5, baseY);
        final tip = base + Offset(lean * height, -height);
        final control = base + Offset(lean * height * 0.4, -height * 0.55);
        final path = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
        canvas.drawPath(path, paint..strokeWidth = 2.2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaterSceneryPainter oldDelegate) => oldDelegate.swayPhase != swayPhase;
}
