import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The abstract "water" backdrop for Names of Allah: soft horizontal wave
/// curves over the app's own teal, not a photorealistic water texture or a
/// new blue palette. Lighter bands blend [AppPalette.parchment] over the
/// teal fill at low alpha; darker bands blend [AppPalette.ink] — both
/// existing tokens, no new hex values, since a flat teal has no
/// lighter/darker variant of its own to reach for. Pure geometry, painted
/// once; `shouldRepaint` only fires on a real size change.
class WaterSurfacePainter extends CustomPainter {
  const WaterSurfacePainter({this.seed = 7});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    // 2-3 soft wave bands at different depths — alternating a touch
    // lighter/darker than the base fill so they read as gentle water
    // texture, not a UI element competing for attention.
    final bands = 2 + rng.nextInt(2);
    for (var i = 0; i < bands; i++) {
      final lighter = i.isEven;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = (lighter ? AppPalette.parchment : AppPalette.ink)
            .withValues(alpha: lighter ? 0.09 : 0.07);

      final baseY = size.height * (0.22 + i * (0.56 / math.max(1, bands - 1)).clamp(0.18, 0.6)) +
          rng.nextDouble() * 16 - 8;
      final amplitude = 8 + rng.nextDouble() * 8;
      final wavelength = size.width / (1.4 + rng.nextDouble() * 1.2);
      final phase = rng.nextDouble() * 2 * math.pi;

      final path = Path()..moveTo(0, baseY);
      const step = 10.0;
      for (var x = 0.0; x <= size.width; x += step) {
        final y = baseY + amplitude * math.sin(x / wavelength * 2 * math.pi + phase);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterSurfacePainter oldDelegate) => oldDelegate.seed != seed;
}
