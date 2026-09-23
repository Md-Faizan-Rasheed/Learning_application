import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Explore tab's backdrop for "Find My Ayah": a night sky the
/// constellation of categories/situations is drawn against (see
/// `constellation_map.dart`) instead of the tree/canopy this replaced.
/// Deterministic ambient stars (a fixed seed, not ambient `Random()`) plus
/// a soft crescent moon and a low mosque-dome silhouette along the
/// bottom — purely decorative, never interactive.
///
/// Colors here are a deliberate one-off exemption from the app's shared
/// ivory/gold [AppPalette] — the same exemption `CanopyHero` used to carry
/// before this replaced it: a hero backdrop is allowed its own world so
/// long as the chrome around it (header, tabs, cards) stays on the shared
/// palette.
class ConstellationSkyPainter extends CustomPainter {
  const ConstellationSkyPainter({required this.twinklePhase, this.seed = 7});

  /// 0..2π — advances slowly so the ambient star field twinkles gently.
  final double twinklePhase;
  final int seed;

  static const Color skyTop = Color(0xFF0A1130);
  static const Color skyBottom = Color(0xFF1C2452);
  static const Color moonColor = Color(0xFFF3ECD8);
  static const Color domeColor = Color(0xFF141C42);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyBottom],
        ).createShader(rect),
    );

    _paintMoon(canvas, size);
    _paintAmbientStars(canvas, size);
    _paintSkyline(canvas, size);
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.16);
    final radius = size.shortestSide * 0.07;

    // Soft glow halo behind the crescent.
    canvas.drawCircle(
      center,
      radius * 2.4,
      Paint()
        ..color = moonColor.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // A crescent: a filled circle with a second, offset circle cut out of
    // it via an even-odd fill.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..addOval(Rect.fromCircle(
        center: center + Offset(radius * 0.42, -radius * 0.12),
        radius: radius * 0.92,
      ));
    canvas.drawPath(path, Paint()..color = moonColor.withValues(alpha: 0.92));
  }

  void _paintAmbientStars(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    const count = 46;
    for (var i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height * 0.86; // keep clear of the skyline
      final baseRadius = 0.6 + rng.nextDouble() * 1.5;
      final phase = rng.nextDouble() * 2 * math.pi;
      final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(twinklePhase * 1.3 + phase));
      canvas.drawCircle(
        Offset(dx, dy),
        baseRadius,
        Paint()..color = Colors.white.withValues(alpha: twinkle.clamp(0.15, 1.0) * 0.85),
      );
    }
  }

  void _paintSkyline(Canvas canvas, Size size) {
    final baseY = size.height * 0.94;
    final paint = Paint()..color = domeColor;

    // A single low, wide dome silhouette plus a slender minaret — kept
    // simple and low-contrast so it grounds the scene without competing
    // with the constellation above it.
    canvas.drawRect(Rect.fromLTWH(0, baseY, size.width, size.height - baseY), paint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.28, baseY), radius: size.width * 0.09),
      math.pi,
      math.pi,
      true,
      paint,
    );

    final minaretX = size.width * 0.62;
    final minaretWidth = size.width * 0.018;
    final minaretHeight = size.shortestSide * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(minaretX - minaretWidth / 2, baseY - minaretHeight, minaretWidth, minaretHeight),
      paint,
    );
    canvas.drawCircle(Offset(minaretX, baseY - minaretHeight), minaretWidth * 1.4, paint);
  }

  @override
  bool shouldRepaint(covariant ConstellationSkyPainter oldDelegate) =>
      oldDelegate.twinklePhase != twinklePhase;
}
