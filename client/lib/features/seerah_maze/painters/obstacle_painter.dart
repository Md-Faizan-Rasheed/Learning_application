import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../constants/maze_colors.dart';
import '../models/maze_cell.dart';
import 'maze_geometry.dart';

/// A6 — draws the patrolling caravans and the sandstorm.
///
/// Takes already-resolved positions rather than the [ObstacleField]
/// itself, so the painter stays a pure function of its inputs and the
/// "where is the caravan at time t" logic has exactly one home (the
/// mechanic, which is unit-tested) rather than being half-reimplemented
/// here.
///
/// Allocates no per-frame lists: the swirl positions are computed inline
/// from a fixed angle step.
class ObstaclePainter extends CustomPainter {
  const ObstaclePainter({
    required this.geometry,
    required this.caravanCells,
    required this.blockedCell,
    required this.warningCell,
    required this.swirlPhase,
    required this.warningPulse,
  });

  final MazeGeometry geometry;

  /// Where each caravan is right now.
  final Set<MazeCoord> caravanCells;

  /// The cell the storm has closed, if any.
  final MazeCoord? blockedCell;

  /// The cell about to close, during its warning window.
  final MazeCoord? warningCell;

  /// 0..1 looping — spins the storm's swirl.
  final double swirlPhase;

  /// 0..1 looping — pulses the warning ring.
  final double warningPulse;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWarning(canvas);
    _paintStorm(canvas);
    _paintCaravans(canvas);
  }

  /// The one-second heads-up before a cell closes: a pulsing dashed ring,
  /// so the player can see it coming rather than walking into a surprise.
  void _paintWarning(Canvas canvas) {
    final cell = warningCell;
    if (cell == null) return;
    final cellSize = geometry.cellSize;
    final center = geometry.centerOf(cell);
    final pulse = 0.6 + 0.4 * math.sin(warningPulse * 2 * math.pi);
    final radius = cellSize * 0.34;

    final paint = Paint()
      ..color = MazeColors.stormWarning.withValues(alpha: 0.4 + 0.45 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, cellSize * 0.05)
      ..strokeCap = StrokeCap.round;

    // Dashes drawn as arc segments — a dashed ring reads as "caution"
    // rather than as a solid decorative circle.
    const segments = 8;
    const sweep = (2 * math.pi / segments) * 0.55;
    for (var i = 0; i < segments; i++) {
      final start = (2 * math.pi / segments) * i + warningPulse * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  /// A closed cell: a dense swirl the player can read as "not through
  /// here", drawn as orbiting grains rather than a flat tint so it isn't
  /// mistaken for ordinary sand.
  void _paintStorm(Canvas canvas) {
    final cell = blockedCell;
    if (cell == null) return;
    final cellSize = geometry.cellSize;
    final center = geometry.centerOf(cell);
    final radius = cellSize * 0.4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          MazeColors.stormCore.withValues(alpha: 0.85),
          MazeColors.stormCore.withValues(alpha: 0.15),
        ]),
    );

    final grain = Paint()..color = MazeColors.stormGrain;
    const grains = 10;
    final grainRadius = math.max(0.8, cellSize * 0.035);
    for (var i = 0; i < grains; i++) {
      // Two interleaved rings turning at different rates reads as a
      // churn rather than a rigid rotation.
      final ring = i.isEven ? 0.5 : 0.78;
      final speed = i.isEven ? 1.0 : -0.7;
      final angle = (swirlPhase * speed + i / grains) * 2 * math.pi;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius * ring,
          center.dy + math.sin(angle) * radius * ring,
        ),
        grainRadius,
        grain,
      );
    }
  }

  /// A camel silhouette — a body with two humps, a neck and legs. Kept a
  /// simple opaque shape (no face, consistent with this feature's rule
  /// that characters are faceless) and clearly taller than the player's
  /// marker so it reads as an obstacle, not a collectible.
  void _paintCaravans(Canvas canvas) {
    if (caravanCells.isEmpty) return;
    final cellSize = geometry.cellSize;
    final fill = Paint()..color = MazeColors.caravanBody;

    for (final coord in caravanCells) {
      final center = geometry.centerOf(coord);
      final w = cellSize * 0.34;
      final h = cellSize * 0.2;
      final baseY = center.dy + h * 0.7;

      final body = Path()
        ..moveTo(center.dx - w, baseY)
        // Two humps across the back.
        ..quadraticBezierTo(
            center.dx - w * 0.75, baseY - h * 1.9, center.dx - w * 0.2, baseY - h * 0.6)
        ..quadraticBezierTo(
            center.dx + w * 0.2, baseY - h * 2.0, center.dx + w * 0.7, baseY - h * 0.5)
        // Neck up and head over.
        ..lineTo(center.dx + w * 0.78, baseY - h * 2.2)
        ..lineTo(center.dx + w, baseY - h * 2.2)
        ..lineTo(center.dx + w * 0.95, baseY - h * 0.4)
        ..lineTo(center.dx + w, baseY)
        ..close();
      canvas.drawPath(body, fill);

      // Legs.
      final leg = Paint()
        ..color = MazeColors.caravanBody
        ..strokeWidth = math.max(1.2, cellSize * 0.045)
        ..strokeCap = StrokeCap.round;
      for (final dx in [-w * 0.6, -w * 0.15, w * 0.35, w * 0.7]) {
        canvas.drawLine(
          Offset(center.dx + dx, baseY),
          Offset(center.dx + dx, baseY + h * 0.9),
          leg,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ObstaclePainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.blockedCell != blockedCell ||
      oldDelegate.warningCell != warningCell ||
      oldDelegate.swirlPhase != swirlPhase ||
      oldDelegate.warningPulse != warningPulse ||
      !_sameCells(oldDelegate.caravanCells, caravanCells);

  static bool _sameCells(Set<MazeCoord> a, Set<MazeCoord> b) =>
      a.length == b.length && a.containsAll(b);
}
