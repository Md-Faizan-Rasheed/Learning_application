import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One connecting segment of the campaign's winding path, from one stage
/// node's center to the next.
class CampaignPathSegment {
  const CampaignPathSegment({
    required this.start,
    required this.end,
    required this.traveled,
  });

  final Offset start;
  final Offset end;

  /// True if the destination stage has been reached (completed or current) —
  /// drawn as a solid, colored line. False (destination still locked) draws
  /// a dashed, muted line instead.
  final bool traveled;
}

/// Draws the S-curved line connecting campaign stage nodes, matching the
/// winding-path mockup: a smooth cubic curve per segment, solid/colored
/// through stages already reached and dashed/muted ahead of them.
class CampaignPathPainter extends CustomPainter {
  const CampaignPathPainter({
    required this.segments,
    required this.traveledColor,
    required this.aheadColor,
    this.strokeWidth = 4.0,
    this.dotProgress,
    this.dotColor,
  });

  final List<CampaignPathSegment> segments;
  final Color traveledColor;
  final Color aheadColor;
  final double strokeWidth;

  /// 0..1 position of the ambient traveling dot along the *traveled*
  /// (cleared) portion of the path only — null or an empty traveled portion
  /// means no dot is drawn. Purely decorative, not tied to any real event;
  /// driven by a single looping AnimationController shared by the whole
  /// screen (see CampaignMapScreen), never one controller per node.
  final double? dotProgress;
  final Color? dotColor;

  Path _segmentPath(CampaignPathSegment segment) {
    final path = Path()..moveTo(segment.start.dx, segment.start.dy);
    final midY = (segment.start.dy + segment.end.dy) / 2;
    path.cubicTo(
      segment.start.dx, midY,
      segment.end.dx, midY,
      segment.end.dx, segment.end.dy,
    );
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final traveledPaint = Paint()
      ..color = traveledColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final aheadPaint = Paint()
      ..color = aheadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final traveledPath = Path();
    for (final segment in segments) {
      final path = _segmentPath(segment);
      if (segment.traveled) {
        canvas.drawPath(path, traveledPaint);
        traveledPath.addPath(path, Offset.zero);
      } else {
        canvas.drawPath(_dashed(path, dashWidth: 6, gapWidth: 8), aheadPaint);
      }
    }

    if (dotProgress != null) {
      _paintTravelingDot(canvas, traveledPath, dotProgress!, dotColor ?? traveledColor);
    }
  }

  void _paintTravelingDot(Canvas canvas, Path traveledPath, double t, Color color) {
    final metrics = traveledPath.computeMetrics().toList();
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    if (totalLength <= 0) return;

    var target = t.clamp(0.0, 1.0) * totalLength;
    for (final metric in metrics) {
      if (target <= metric.length) {
        final tangent = metric.getTangentForOffset(target);
        if (tangent != null) _drawGlowDot(canvas, tangent.position, color);
        return;
      }
      target -= metric.length;
    }
  }

  void _drawGlowDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 9, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(center, 5, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawCircle(center, 2.4, Paint()..color = color.withValues(alpha: 0.95));
  }

  Path _dashed(Path source, {required double dashWidth, required double gapWidth}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashWidth : gapWidth);
        if (draw) {
          dashed.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant CampaignPathPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.traveledColor != traveledColor ||
      oldDelegate.aheadColor != aheadColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dotProgress != dotProgress ||
      oldDelegate.dotColor != dotColor;
}

/// Traces a CircularProgressIndicator-style arc around a node's border,
/// filling clockwise from the top proportionally to [progress]. Used by the
/// current stage's node instead of a flat filled circle.
class NodeProgressRingPainter extends CustomPainter {
  const NodeProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 4.0,
  });

  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2; // 12 o'clock
    canvas.drawArc(rect, startAngle, 2 * math.pi * clamped, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant NodeProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
