import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Convenience wrapper for the common case: put [AmbientBackdrop] full-bleed
/// behind a screen's existing body content in one call, instead of hand
/// -writing a `Stack` at every call site.
class ScreenWithAmbientBackdrop extends StatelessWidget {
  const ScreenWithAmbientBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AmbientBackdrop()),
        child,
      ],
    );
  }
}

/// A static geometric texture shared by every screen: an 8-point-star motif
/// tiled at low opacity over the parchment background, evoking manuscript
/// tilework ornament without competing with foreground content. Deliberately
/// static (no animation) — this replaces the previous animated starfield
/// atmosphere, which read as a "space" theme at odds with the app's identity.
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: GeometricPatternPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Tiles an 8-point star outline across the canvas at a fixed low opacity.
/// Pure geometry, computed per paint — no image asset, no per-frame work
/// (the canvas only repaints when its size changes). Public so a screen can
/// paint the same motif directly in a different tone (e.g. a light stroke
/// over a solid-color header) rather than only via the default [AmbientBackdrop].
class GeometricPatternPainter extends CustomPainter {
  const GeometricPatternPainter({this.color, this.opacity = 0.10});

  /// Defaults to [AppPalette.deepTeal] — the tone used against the app's
  /// parchment background everywhere except where a caller overrides it.
  final Color? color;
  final double opacity;

  static const double _tileSize = 56;
  static const double _outerRadius = 20;
  static const double _innerRadius = 8;

  Path _eightPointStar(Offset center) {
    final path = Path();
    const points = 8;
    for (var i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final radius = i.isEven ? _outerRadius : _innerRadius;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = (color ?? AppPalette.deepTeal).withValues(alpha: opacity);

    final columns = (size.width / _tileSize).ceil() + 1;
    final rows = (size.height / _tileSize).ceil() + 1;

    for (var row = -1; row < rows; row++) {
      // Offset alternating rows by half a tile — the classic brick-like
      // tessellation Islamic star-tile patterns use, rather than a plain grid.
      final rowOffset = row.isOdd ? _tileSize / 2 : 0.0;
      for (var col = -1; col < columns; col++) {
        final center = Offset(
          col * _tileSize + rowOffset,
          row * _tileSize,
        );
        canvas.drawPath(_eightPointStar(center), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GeometricPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
