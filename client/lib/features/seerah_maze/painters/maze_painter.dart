import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../constants/maze_destination_icons.dart';
import '../logic/maze_generator.dart';
import '../logic/mechanics/teleport_network.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import '../models/maze_level.dart';
import 'maze_geometry.dart';

/// Static layer: the parchment board panel and every wall. Never depends
/// on anything that changes frame-to-frame (player position, time,
/// collected stars), so the board widget records this once per level into
/// a cached `ui.Picture` and replays it every frame at near-zero cost
/// (see ui/maze_board.dart) — this class stays usable as a plain
/// CustomPainter on its own too (e.g. in tests).
class MazeWallsPainter extends CustomPainter {
  const MazeWallsPainter({
    required this.maze,
    required this.geometry,
    this.revealProgress = 1,
    this.wallColor,
    this.glowColor,
  });

  final MazeGenerationResult maze;
  final MazeGeometry geometry;

  /// 0..1 — only walls belonging to a cell whose start-distance fraction
  /// is at or below this are drawn, for the level-start "maze builds
  /// outward from the start" stagger. 1 (the default) draws everything,
  /// which is also what every frame after the build animation finishes
  /// uses.
  final double revealProgress;

  /// B2 — a level's environment theme tints the wall/glow rather than
  /// replacing MazeColors outright, so every level still reads as the
  /// same gold-walled maze under a different cast of light. Null (any
  /// caller that doesn't pass a theme) keeps the plain colors.
  final Color? wallColor;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(
      geometry.origin.dx,
      geometry.origin.dy,
      maze.size * geometry.cellSize,
      maze.size * geometry.cellSize,
    );
    final panelRRect = RRect.fromRectAndRadius(
      boardRect,
      const Radius.circular(MazeConstants.boardCornerRadius),
    );
    canvas.drawRRect(panelRRect, Paint()..color = MazeColors.boardPanel);
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = MazeColors.boardPanelShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final maxDistance = _maxDistance();
    final segments = <(Offset, Offset)>[];
    for (var row = 0; row < maze.size; row++) {
      for (var col = 0; col < maze.size; col++) {
        final coord = MazeCoord(row, col);
        if (revealProgress < 1 && _revealFraction(coord, maxDistance) > revealProgress) {
          continue;
        }
        final cell = maze.cellAt(coord);
        final rect = geometry.rectOf(coord);
        for (final direction in MazeDirection.values) {
          if (cell.isOpen(direction)) continue;
          segments.add(_wallSegment(rect, direction));
        }
      }
    }

    final glowPaint = Paint()
      ..color = glowColor ?? MazeColors.wallGlow
      ..style = PaintingStyle.stroke
      ..strokeWidth = MazeConstants.wallStrokeWidth + MazeConstants.wallGlowBlur
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, MazeConstants.wallGlowBlur);
    final outlinePaint = Paint()
      ..color = MazeColors.wallOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = MazeConstants.wallStrokeWidth + 2
      ..strokeCap = StrokeCap.round;
    final wallPaint = Paint()
      ..color = wallColor ?? MazeColors.wall
      ..style = PaintingStyle.stroke
      ..strokeWidth = MazeConstants.wallStrokeWidth
      ..strokeCap = StrokeCap.round;

    for (final (from, to) in segments) {
      canvas.drawLine(from, to, glowPaint);
    }
    for (final (from, to) in segments) {
      canvas.drawLine(from, to, outlinePaint);
    }
    for (final (from, to) in segments) {
      canvas.drawLine(from, to, wallPaint);
    }
  }

  int _maxDistance() {
    var max = 0;
    for (final row in maze.distancesFromStart) {
      for (final distance in row) {
        if (distance > max) max = distance;
      }
    }
    return max;
  }

  double _revealFraction(MazeCoord coord, int maxDistance) {
    if (maxDistance <= 0) return 0;
    return maze.distancesFromStart[coord.row][coord.col] / maxDistance;
  }

  (Offset, Offset) _wallSegment(Rect rect, MazeDirection direction) {
    switch (direction) {
      case MazeDirection.north:
        return (rect.topLeft, rect.topRight);
      case MazeDirection.south:
        return (rect.bottomLeft, rect.bottomRight);
      case MazeDirection.east:
        return (rect.topRight, rect.bottomRight);
      case MazeDirection.west:
        return (rect.topLeft, rect.bottomLeft);
    }
  }

  @override
  bool shouldRepaint(covariant MazeWallsPainter oldDelegate) =>
      !identical(oldDelegate.maze, maze) ||
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.revealProgress != revealProgress;
}

/// Dynamic layer painted every frame above the cached walls picture: the
/// destination's pulsing glow + bobbing glyph, the collectible stars'
/// sparkle, and (on cave levels) the uncollected light orbs.
class MazeDecorationsPainter extends CustomPainter {
  const MazeDecorationsPainter({
    required this.maze,
    required this.level,
    required this.geometry,
    required this.pulsePhase,
    required this.sparklePhase,
    required this.collectedStars,
    required this.playerPosition,
    this.hintCells = const [],
    this.lightOrbs = const {},
    this.oneWayArrows = const {},
    this.sandCells = const {},
    this.teleportPairs = const [],
    this.factScrollCell,
  });

  final MazeGenerationResult maze;
  final MazeLevel level;
  final MazeGeometry geometry;

  /// 0..1, looping — drives the destination ring glow/scale and bob.
  final double pulsePhase;

  /// 0..1, looping — drives star rotation/sparkle.
  final double sparklePhase;

  final Set<MazeCoord> collectedStars;
  final MazeCoord playerPosition;

  /// The hint system's next-steps highlight — cleared by the caller after
  /// MazeConstants.hintHighlightDuration (owned by the HUD/hint button,
  /// added in a later build step).
  final List<MazeCoord> hintCells;

  /// A2 — uncollected light orbs on a cave level. Empty everywhere else.
  final Set<MazeCoord> lightOrbs;

  /// A4 — arrow tiles and the direction each one forces.
  final Map<MazeCoord, MazeDirection> oneWayArrows;

  /// A4 — slippery sand cells.
  final Set<MazeCoord> sandCells;

  /// A5 — linked tent pairs.
  final List<MazeTeleportPair> teleportPairs;

  /// B4 — this level's one collectible fact scroll, or null once it's
  /// been collected (the caller simply stops passing a cell).
  final MazeCoord? factScrollCell;

  @override
  void paint(Canvas canvas, Size size) {
    // Sand goes down first: it's ground the other decorations sit on.
    _paintSand(canvas);
    _paintHints(canvas);
    _paintOneWayArrows(canvas);
    _paintTeleports(canvas);
    _paintStars(canvas);
    _paintLightOrbs(canvas);
    _paintFactScroll(canvas);
    _paintDestination(canvas);
  }

  /// B4 — a rolled parchment: a rounded bar with a small cap at each end,
  /// tied with a ribbon — a distinct silhouette from the star/orb/key
  /// glyphs already on the board, so it reads as its own kind of thing.
  void _paintFactScroll(Canvas canvas) {
    final cell = factScrollCell;
    if (cell == null) return;
    final cellSize = geometry.cellSize;
    final center = geometry.centerOf(cell);
    final bob = math.sin(sparklePhase * 2 * math.pi) * cellSize * 0.03;
    final scrollCenter = center.translate(0, bob);

    final w = cellSize * 0.34;
    final h = cellSize * 0.14;
    final barRect = Rect.fromCenter(center: scrollCenter, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(h / 2)),
      Paint()..color = MazeColors.scrollParchment,
    );
    // End caps, slightly darker, reading as the rolled tube ends.
    for (final dx in [-w / 2, w / 2]) {
      canvas.drawCircle(
        scrollCenter.translate(dx, 0),
        h * 0.55,
        Paint()..color = MazeColors.scrollCap,
      );
    }
    // Ribbon tie across the middle.
    canvas.drawRect(
      Rect.fromCenter(center: scrollCenter, width: cellSize * 0.04, height: h * 1.3),
      Paint()..color = MazeColors.destinationIcon,
    );
  }

  /// A5 — a tent: a glowing triangle, with one pip per pair index below it
  /// so two pairs on the same board are distinguishable by count as well
  /// as by glow color.
  void _paintTeleports(Canvas canvas) {
    if (teleportPairs.isEmpty) return;
    final cellSize = geometry.cellSize;
    final breathe = 0.75 + 0.25 * math.sin(pulsePhase * 2 * math.pi);

    for (final pair in teleportPairs) {
      final color = MazeColors.teleportGlowFor(pair.index);
      for (final coord in [pair.a, pair.b]) {
        final center = geometry.centerOf(coord);

        // Halo first, so the tent itself stays crisp on top of it.
        final haloRadius = cellSize * 0.34 * breathe;
        canvas.drawCircle(
          center,
          haloRadius,
          Paint()
            ..shader = ui.Gradient.radial(center, haloRadius, [
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0),
            ]),
        );

        final half = cellSize * 0.2;
        final tent = Path()
          ..moveTo(center.dx, center.dy - half)
          ..lineTo(center.dx + half * 0.85, center.dy + half * 0.6)
          ..lineTo(center.dx - half * 0.85, center.dy + half * 0.6)
          ..close();
        canvas.drawPath(tent, Paint()..color = color);
        canvas.drawPath(
          tent,
          Paint()
            ..color = MazeColors.wallOutline.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, cellSize * 0.022),
        );

        // Pips: the shape cue identifying which pair this tent belongs to.
        final pipRadius = math.max(0.8, cellSize * 0.028);
        final pipCount = pair.index + 1;
        final pipSpacing = pipRadius * 3;
        final pipStart = center.dx - (pipCount - 1) * pipSpacing / 2;
        for (var i = 0; i < pipCount; i++) {
          canvas.drawCircle(
            Offset(pipStart + i * pipSpacing, center.dy + half * 0.85),
            pipRadius,
            Paint()..color = color,
          );
        }
      }
    }
  }

  /// A4 — a sand cell reads as a lighter patch of ground with a few
  /// stipple dots, so it's recognisable as a *texture* rather than only as
  /// a tint (the "never color alone" rule again).
  void _paintSand(Canvas canvas) {
    if (sandCells.isEmpty) return;
    final cellSize = geometry.cellSize;
    final fill = Paint()..color = MazeColors.sandFill;
    final stipple = Paint()..color = MazeColors.sandStipple;
    final dotRadius = math.max(0.6, cellSize * 0.028);

    for (final coord in sandCells) {
      final rect = geometry.rectOf(coord).deflate(cellSize * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.14)),
        fill,
      );
      // A fixed stipple pattern (not random) so the texture never shimmers
      // between frames and costs nothing to recompute.
      for (final offset in const [
        Offset(0.3, 0.32),
        Offset(0.66, 0.4),
        Offset(0.44, 0.63),
        Offset(0.74, 0.72),
        Offset(0.26, 0.76),
      ]) {
        canvas.drawCircle(
          Offset(rect.left + rect.width * offset.dx, rect.top + rect.height * offset.dy),
          dotRadius,
          stipple,
        );
      }
    }
  }

  /// A4 — the arrow on a one-way tile, drawn as a chevron pointing the
  /// way the tile forces.
  void _paintOneWayArrows(Canvas canvas) {
    if (oneWayArrows.isEmpty) return;
    final cellSize = geometry.cellSize;
    final paint = Paint()
      ..color = MazeColors.oneWayArrow
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, cellSize * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final entry in oneWayArrows.entries) {
      final center = geometry.centerOf(entry.key);
      final angle = switch (entry.value) {
        MazeDirection.north => -math.pi / 2,
        MazeDirection.south => math.pi / 2,
        MazeDirection.east => 0.0,
        MazeDirection.west => math.pi,
      };
      final arm = cellSize * 0.16;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      // A chevron: two strokes meeting at a point, pointing +x before the
      // rotation above aims it.
      final chevron = Path()
        ..moveTo(-arm * 0.5, -arm)
        ..lineTo(arm * 0.6, 0)
        ..lineTo(-arm * 0.5, arm);
      canvas.drawPath(chevron, paint);
      canvas.restore();
    }
  }

  /// A warm little flame-dot, deliberately a different *shape* from the
  /// collectible stars (a soft circle with a halo, not a star outline) so
  /// the two read apart without relying on color alone.
  void _paintLightOrbs(Canvas canvas) {
    if (lightOrbs.isEmpty) return;
    final breathe = 0.8 + 0.2 * math.sin(sparklePhase * 2 * math.pi);
    final coreRadius = geometry.cellSize * 0.13 * breathe;
    final haloRadius = geometry.cellSize * 0.3 * breathe;
    for (final coord in lightOrbs) {
      final center = geometry.centerOf(coord);
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = ui.Gradient.radial(center, haloRadius, [
            MazeColors.lightMarkerGlow.withValues(alpha: 0.5),
            MazeColors.lightMarkerGlow.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(center, coreRadius, Paint()..color = MazeColors.lightMarkerCore);
    }
  }

  void _paintHints(Canvas canvas) {
    if (hintCells.isEmpty) return;
    final pulse = 0.5 + 0.5 * math.sin(pulsePhase * 2 * math.pi);
    final paint = Paint()
      ..color = MazeColors.destinationRing.withValues(alpha: 0.25 + 0.15 * pulse);
    for (final coord in hintCells) {
      final rect = geometry.rectOf(coord).deflate(geometry.cellSize * 0.08);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(geometry.cellSize * 0.2)), paint);
    }
  }

  void _paintStars(Canvas canvas) {
    for (final coord in maze.starCoords) {
      if (collectedStars.contains(coord)) continue;
      final center = geometry.centerOf(coord);
      final sparkle = 0.75 + 0.25 * math.sin(sparklePhase * 2 * math.pi);
      _drawStarShape(
        canvas,
        center,
        geometry.cellSize * 0.16 * sparkle,
        sparklePhase * 2 * math.pi,
      );
    }
  }

  void _drawStarShape(Canvas canvas, Offset center, double radius, double rotation) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final angle = rotation + i * math.pi / points;
      final r = i.isEven ? radius : radius * 0.45;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = MazeColors.star);
    canvas.drawCircle(center, radius * 0.22, Paint()..color = MazeColors.starSparkle);
  }

  void _paintDestination(Canvas canvas) {
    final center = geometry.centerOf(maze.destination);
    final bob = math.sin(pulsePhase * 2 * math.pi) * geometry.cellSize * 0.06;
    final glyphCenter = center + Offset(0, bob);
    final ringRadius = geometry.cellSize * (0.42 + 0.06 * math.sin(pulsePhase * 2 * math.pi));

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = MazeColors.destinationRing.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    _drawDestinationGlyph(canvas, glyphCenter, geometry.cellSize * 0.3, level.destinationKind);
  }

  void _drawDestinationGlyph(
      Canvas canvas, Offset center, double radius, MazeDestinationKind kind) {
    if (kind == MazeDestinationKind.kaaba) {
      final rect = Rect.fromCenter(center: center, width: radius * 1.3, height: radius * 1.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.12)),
        Paint()..color = MazeColors.wallOutline,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top + rect.height * 0.3, rect.width, rect.height * 0.14),
        Paint()..color = MazeColors.destinationRing,
      );
      return;
    }
    _drawIconGlyph(canvas, center, radius * 1.5, mazeDestinationIconFor(kind));
  }

  void _drawIconGlyph(Canvas canvas, Offset center, double fontSize, IconData icon) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: MazeColors.destinationIcon,
        ),
      )
      ..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant MazeDecorationsPainter oldDelegate) => true;
}
