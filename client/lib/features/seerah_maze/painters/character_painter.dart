import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../constants/maze_colors.dart';

/// The player sprite: either a faceless neutral silhouette, or — for a
/// level where the traveler is the Prophet Muhammad ﷺ — a glowing
/// light/star marker with no human figure at all, per this feature's
/// depiction rules. Also draws the ground shadow and the fading trail of
/// recent positions. A per-frame dynamic painter (bob/breathe/trail all
/// animate), so it is intentionally cheap: a handful of filled shapes, no
/// path construction that allocates per frame beyond simple Offsets.
class CharacterPainter extends CustomPainter {
  const CharacterPainter({
    required this.center,
    required this.cellSize,
    required this.usesLightMarker,
    required this.bobOffset,
    required this.scale,
    required this.trail,
    required this.shakeOffset,
  });

  final Offset center;
  final double cellSize;
  final bool usesLightMarker;

  /// Vertical offset (walk bob while moving, or idle breathing settles to
  /// 0) in logical pixels.
  final double bobOffset;

  /// Idle-breathing scale multiplier around 1.0.
  final double scale;

  /// Oldest-first recent positions; drawn with increasing opacity toward
  /// the current position.
  final List<Offset> trail;

  /// Horizontal shake offset while bumping into a wall; 0 otherwise.
  final double shakeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrail(canvas);
    final drawCenter = center + Offset(shakeOffset, bobOffset);
    _paintGroundShadow(canvas, drawCenter);
    if (usesLightMarker) {
      _paintLightMarker(canvas, drawCenter);
    } else {
      _paintSilhouette(canvas, drawCenter);
    }
  }

  void _paintTrail(Canvas canvas) {
    if (trail.isEmpty) return;
    final dotRadius = cellSize * 0.07;
    for (var i = 0; i < trail.length; i++) {
      final fraction = (i + 1) / trail.length;
      canvas.drawCircle(
        trail[i],
        dotRadius * (0.5 + 0.5 * fraction),
        Paint()..color = MazeColors.trail.withValues(alpha: 0.28 * fraction),
      );
    }
  }

  void _paintGroundShadow(Canvas canvas, Offset drawCenter) {
    final shadowCenter = Offset(drawCenter.dx, center.dy + cellSize * 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: shadowCenter, width: cellSize * 0.5, height: cellSize * 0.16),
      Paint()..color = MazeColors.characterShadow,
    );
  }

  void _paintSilhouette(Canvas canvas, Offset drawCenter) {
    final bodyPaint = Paint()..color = MazeColors.characterFill;
    final headRadius = cellSize * 0.15 * scale;
    final bodyWidth = cellSize * 0.26 * scale;
    final bodyHeight = cellSize * 0.34 * scale;

    final headCenter = Offset(drawCenter.dx, drawCenter.dy - bodyHeight * 0.55 - headRadius * 0.6);
    final bodyRect = Rect.fromCenter(
      center: Offset(drawCenter.dx, drawCenter.dy - bodyHeight * 0.1),
      width: bodyWidth,
      height: bodyHeight,
    );

    // No facial features by construction — a plain filled silhouette.
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyWidth * 0.5)),
      bodyPaint,
    );
    canvas.drawCircle(headCenter, headRadius, bodyPaint);
  }

  void _paintLightMarker(Canvas canvas, Offset drawCenter) {
    final outerRadius = cellSize * 0.32 * scale;
    canvas.drawCircle(
      drawCenter,
      outerRadius,
      Paint()
        ..color = MazeColors.lightMarkerGlow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      drawCenter,
      outerRadius * 0.55,
      Paint()..color = MazeColors.lightMarkerCore,
    );

    final rayPaint = Paint()
      ..color = MazeColors.lightMarkerGlow
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final rayStart = drawCenter + Offset(math.cos(angle), math.sin(angle)) * outerRadius * 0.7;
      final rayEnd = drawCenter + Offset(math.cos(angle), math.sin(angle)) * outerRadius * 1.15;
      canvas.drawLine(rayStart, rayEnd, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CharacterPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.bobOffset != bobOffset ||
      oldDelegate.scale != scale ||
      oldDelegate.shakeOffset != shakeOffset ||
      oldDelegate.trail != trail;
}
