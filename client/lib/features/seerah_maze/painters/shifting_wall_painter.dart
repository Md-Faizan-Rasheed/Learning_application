import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../models/maze_direction.dart';
import '../models/maze_passage_edge.dart';
import 'maze_geometry.dart';

/// A7 — draws the passages that are currently shut, plus the glow cue on
/// the ones about to flip.
///
/// This is its own thin dynamic layer precisely so the cached wall picture
/// never has to be rebuilt when a toggle fires: a shut passage is drawn
/// here, on top, in the same style as a real wall. Rebuilding the picture
/// every 15 seconds would be far more expensive than painting one or two
/// short bars per frame.
class ShiftingWallPainter extends CustomPainter {
  const ShiftingWallPainter({
    required this.geometry,
    required this.closedEdges,
    required this.warningEdges,
    required this.warningPulse,
  });

  final MazeGeometry geometry;
  final Set<MazePassageEdge> closedEdges;
  final Set<MazePassageEdge> warningEdges;

  /// 0..1 looping — drives the pre-flip glow.
  final double warningPulse;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in warningEdges) {
      _paintWarning(canvas, edge);
    }
    for (final edge in closedEdges) {
      _paintClosed(canvas, edge);
    }
  }

  /// Matches the look of a real wall so a shut passage reads as solid,
  /// rather than as a decoration the player might try to walk through.
  void _paintClosed(Canvas canvas, MazePassageEdge edge) {
    final cellSize = geometry.cellSize;
    final from = geometry.centerOf(edge.cell);
    final to = geometry.centerOf(edge.otherCell);
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final horizontalPassage = edge.direction == MazeDirection.east;
    final half = cellSize / 2;

    final start = horizontalPassage ? Offset(mid.dx, mid.dy - half) : Offset(mid.dx - half, mid.dy);
    final end = horizontalPassage ? Offset(mid.dx, mid.dy + half) : Offset(mid.dx + half, mid.dy);

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = MazeColors.wallGlow
        ..strokeWidth = MazeConstants.wallStrokeWidth + MazeConstants.wallGlowBlur
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = MazeColors.wall
        ..strokeWidth = MazeConstants.wallStrokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The 1.5s heads-up: the gap itself pulses, so the player can tell
  /// something is about to change there — whichever way it's about to go.
  void _paintWarning(Canvas canvas, MazePassageEdge edge) {
    final cellSize = geometry.cellSize;
    final from = geometry.centerOf(edge.cell);
    final to = geometry.centerOf(edge.otherCell);
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final pulse = 0.5 + 0.5 * math.sin(warningPulse * 2 * math.pi * 2);

    canvas.drawCircle(
      mid,
      cellSize * (0.18 + 0.1 * pulse),
      Paint()..color = MazeColors.shiftingWallCue.withValues(alpha: 0.25 + 0.45 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant ShiftingWallPainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.warningPulse != warningPulse ||
      oldDelegate.closedEdges.length != closedEdges.length ||
      oldDelegate.warningEdges.length != warningEdges.length ||
      !oldDelegate.closedEdges.containsAll(closedEdges) ||
      !oldDelegate.warningEdges.containsAll(warningEdges);
}
