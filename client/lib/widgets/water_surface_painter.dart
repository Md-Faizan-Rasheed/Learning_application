import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The abstract "water" backdrop for Names on Water: thin concentric-ripple
/// and current-line work over the app's own teal, not a photorealistic
/// water texture or a new blue palette — same static/seeded/low-alpha
/// painting philosophy as [GeometricPatternPainter] and [PaperGrainPainter]
/// (see ambient_backdrop.dart, card_stock.dart), just a different motif.
/// Pure geometry, painted once; `shouldRepaint` only fires on a real size
/// change, so this costs nothing per frame regardless of how many pads
/// float on top of it.
class WaterSurfacePainter extends CustomPainter {
  const WaterSurfacePainter({this.seed = 7});

  final int seed;

  static const _rippleGroups = 6;
  static const _ringsPerGroup = 3;
  static const _currentLines = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppPalette.parchment.withValues(alpha: 0.14);

    for (var g = 0; g < _rippleGroups; g++) {
      final center = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final baseRadius = 14 + rng.nextDouble() * 22;
      for (var r = 0; r < _ringsPerGroup; r++) {
        final radius = baseRadius + r * 16;
        final alpha = 0.16 - r * 0.045;
        canvas.drawCircle(
          center,
          radius,
          ringPaint..color = AppPalette.parchment.withValues(alpha: alpha.clamp(0.02, 1.0)),
        );
      }
    }

    final currentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppPalette.parchment.withValues(alpha: 0.08);

    for (var i = 0; i < _currentLines; i++) {
      final baseY = size.height * (0.2 + i * 0.3) + rng.nextDouble() * 20 - 10;
      final amplitude = 6 + rng.nextDouble() * 6;
      final wavelength = size.width / (2 + rng.nextInt(2));
      final path = Path()..moveTo(0, baseY);
      const step = 12.0;
      for (var x = 0.0; x <= size.width; x += step) {
        final y = baseY + amplitude * math.sin(x / wavelength * 2 * math.pi);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterSurfacePainter oldDelegate) => oldDelegate.seed != seed;
}
