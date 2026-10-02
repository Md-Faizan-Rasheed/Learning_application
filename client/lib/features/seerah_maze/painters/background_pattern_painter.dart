import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../constants/maze_colors.dart';

/// A faint, tiled 8-pointed-star motif (two overlapping squares, the
/// classic "rub el hizb" construction) drawn behind the board — procedural,
/// so it needs no image asset. Fully static: it never depends on game
/// state, so the widget hosting it only ever needs to paint it once per
/// size change.
class BackgroundPatternPainter extends CustomPainter {
  const BackgroundPatternPainter({this.tileSize = 56});

  final double tileSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MazeColors.backgroundPattern
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final columns = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final center = Offset(col * tileSize, row * tileSize);
        _drawEightPointStar(canvas, paint, center, tileSize * 0.42);
      }
    }
  }

  void _drawEightPointStar(Canvas canvas, Paint paint, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (final rotation in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.rotate(rotation);
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final angle = i * math.pi / 2;
        final point = Offset(radius * math.cos(angle), radius * math.sin(angle));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BackgroundPatternPainter oldDelegate) =>
      oldDelegate.tileSize != tileSize;
}
