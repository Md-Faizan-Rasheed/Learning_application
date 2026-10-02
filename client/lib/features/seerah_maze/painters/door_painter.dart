import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../constants/maze_door_styles.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import '../models/maze_door.dart';
import 'maze_geometry.dart';

/// A3 — draws the locked doors still barring a passage, and the keys still
/// waiting to be picked up.
///
/// A door is a bar laid across the passage it blocks, with [notches]
/// short ticks cut across it; a key is a small ring-and-shaft glyph. Both
/// carry their kind's shape cue (notch count / icon) as well as its color,
/// so the pairing is readable without relying on hue.
///
/// Only locked doors are passed in, so an opened door simply stops being
/// drawn — the "short opening animation" the spec asks for is the swing
/// handled by [openingDoor]/[openProgress], which the board drives for the
/// one door being opened right now.
class DoorPainter extends CustomPainter {
  const DoorPainter({
    required this.geometry,
    required this.lockedDoors,
    required this.remainingKeys,
    this.openingDoor,
    this.openProgress = 0,
  });

  final MazeGeometry geometry;
  final Set<MazeDoor> lockedDoors;
  final Map<MazeCoord, MazeKeyKind> remainingKeys;

  /// The door currently playing its opening swing, if any.
  final MazeDoor? openingDoor;

  /// 0..1 through that swing.
  final double openProgress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final door in lockedDoors) {
      _paintDoor(canvas, door, 0);
    }
    final opening = openingDoor;
    if (opening != null && openProgress > 0 && openProgress < 1) {
      _paintDoor(canvas, opening, openProgress);
    }
    _paintKeys(canvas);
  }

  void _paintDoor(Canvas canvas, MazeDoor door, double openAmount) {
    final style = mazeDoorStyleFor(door.keyKind);
    final cellSize = geometry.cellSize;
    final from = geometry.centerOf(door.edge.cell);
    final to = geometry.centerOf(door.edge.otherCell);
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);

    // The bar lies across the passage, so it runs perpendicular to the
    // direction of travel through it.
    final horizontalPassage = door.edge.direction == MazeDirection.east;
    final halfLength = cellSize * 0.4;
    final halfThickness = cellSize * 0.09;

    // Opening swings the bar away and fades it out, rather than sliding it
    // into a neighbouring cell where it would overlap the maze.
    final swing = Curves.easeOut.transform(openAmount);
    final alpha = (1 - swing).clamp(0.0, 1.0);
    if (alpha <= 0) return;

    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(swing * math.pi / 2 * (horizontalPassage ? 1 : -1));

    final rect = horizontalPassage
        ? Rect.fromCenter(
            center: Offset.zero,
            width: halfThickness * 2,
            height: halfLength * 2,
          )
        : Rect.fromCenter(
            center: Offset.zero,
            width: halfLength * 2,
            height: halfThickness * 2,
          );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(halfThickness)),
      Paint()..color = style.color.withValues(alpha: alpha),
    );

    // Notches: the shape cue distinguishing one key kind from another.
    final notchPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * alpha)
      ..strokeWidth = math.max(1, cellSize * 0.025)
      ..strokeCap = StrokeCap.round;
    final spacing = halfLength * 2 / (style.notches + 1);
    for (var i = 1; i <= style.notches; i++) {
      final offset = -halfLength + spacing * i;
      if (horizontalPassage) {
        canvas.drawLine(
          Offset(-halfThickness * 0.55, offset),
          Offset(halfThickness * 0.55, offset),
          notchPaint,
        );
      } else {
        canvas.drawLine(
          Offset(offset, -halfThickness * 0.55),
          Offset(offset, halfThickness * 0.55),
          notchPaint,
        );
      }
    }

    canvas.restore();
  }

  void _paintKeys(Canvas canvas) {
    final cellSize = geometry.cellSize;
    for (final entry in remainingKeys.entries) {
      final style = mazeDoorStyleFor(entry.value);
      final center = geometry.centerOf(entry.key);
      final paint = Paint()
        ..color = style.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, cellSize * 0.055)
        ..strokeCap = StrokeCap.round;

      // Ring plus shaft, with the kind's notch count as teeth — a key
      // silhouette rather than a letter or a bare dot.
      final ringRadius = cellSize * 0.13;
      final ringCenter = center.translate(0, -cellSize * 0.08);
      canvas.drawCircle(ringCenter, ringRadius, paint);

      final shaftTop = ringCenter.translate(0, ringRadius);
      final shaftBottom = center.translate(0, cellSize * 0.24);
      canvas.drawLine(shaftTop, shaftBottom, paint);

      final toothLength = cellSize * 0.09;
      for (var i = 0; i < style.notches; i++) {
        final y = shaftBottom.dy - i * cellSize * 0.07;
        canvas.drawLine(
          Offset(shaftBottom.dx, y),
          Offset(shaftBottom.dx + toothLength, y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoorPainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.lockedDoors.length != lockedDoors.length ||
      oldDelegate.remainingKeys.length != remainingKeys.length ||
      oldDelegate.openingDoor != openingDoor ||
      oldDelegate.openProgress != openProgress;
}
