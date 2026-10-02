import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../constants/maze_colors.dart';
import '../models/maze_cell.dart';
import 'maze_geometry.dart';

/// A1/A2 — the fog (and cave-lantern) veil, painted as its own layer above
/// the board so the cached wall picture is never rebuilt for a lighting
/// change.
///
/// Draws in two passes rather than one rect per cell: a single flat veil
/// over the whole board (at the strongest level any cell needs), then a
/// radial-gradient hole punched out around the player with
/// [BlendMode.dstOut], plus one soft rect per remembered cell to lift the
/// veil part-way where the player has already been. That keeps the
/// per-frame cost proportional to the remembered set rather than to the
/// square of the grid size, and gives the lit edge a soft falloff instead
/// of a hard cell-shaped staircase.
///
/// Holds no mutable state and allocates its paints in `paint` only via
/// cheap, reused locals — no per-frame object churn beyond what Canvas
/// itself requires.
class FogPainter extends CustomPainter {
  const FogPainter({
    required this.geometry,
    required this.mazeSize,
    required this.playerCenter,
    required this.rememberedCells,
    required this.lightRadiusInCells,
    required this.rememberedVeil,
    required this.hiddenVeil,
    required this.revealProgress,
    this.destinationGlow,
  });

  final MazeGeometry geometry;
  final int mazeSize;

  /// The player's position in pixels (the animated tween value, not the
  /// grid cell) so the lit circle glides with the character instead of
  /// snapping a cell at a time.
  final Offset playerCenter;

  final Set<MazeCoord> rememberedCells;

  /// Current lit radius, in cells — a plain value rather than a config
  /// read, so the cave lantern's flicker/boost can drive the same painter.
  final double lightRadiusInCells;

  final double rememberedVeil;
  final double hiddenVeil;

  /// 0..1 fade applied to the whole veil when a level opens, so the board
  /// darkens in smoothly rather than popping to black on the first frame.
  final double revealProgress;

  /// A2 — the destination's faint glow showing through the cave veil.
  /// Null outside cave mode, where the destination is already plainly
  /// visible under ordinary fog.
  final FogDestinationGlow? destinationGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (hiddenVeil <= 0 || revealProgress <= 0) return;

    const veilColor = MazeColors.fogVeil;
    final boardRect = Offset.zero & size;

    canvas.saveLayer(boardRect, Paint());

    // Pass 1: the full-strength veil over everything.
    canvas.drawRect(
      boardRect,
      Paint()..color = veilColor.withValues(alpha: hiddenVeil * revealProgress),
    );

    // Pass 2: lift the veil part-way over remembered cells.
    final rememberedLift = (hiddenVeil - rememberedVeil).clamp(0.0, 1.0);
    if (rememberedLift > 0 && rememberedCells.isNotEmpty) {
      final liftPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..color = const Color(0xFF000000).withValues(alpha: rememberedLift);
      for (final coord in rememberedCells) {
        canvas.drawRect(geometry.rectOf(coord), liftPaint);
      }
    }

    // Pass 3: the destination's faint glow bleeding through the dark, so a
    // cave level still hints at where you're headed.
    final glow = destinationGlow;
    if (glow != null && glow.strength > 0) {
      final glowRadius = glow.radiusInCells * geometry.cellSize;
      canvas.drawCircle(
        glow.center,
        glowRadius,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = ui.Gradient.radial(
            glow.center,
            glowRadius,
            [
              const Color(0xFF000000).withValues(alpha: glow.strength * revealProgress),
              const Color(0x00000000),
            ],
            const [0.0, 1.0],
          ),
      );
    }

    // Pass 4: punch a soft-edged hole for the player's own light.
    final lightRadius = math.max(lightRadiusInCells, 0.001) * geometry.cellSize;
    canvas.drawCircle(
      playerCenter,
      lightRadius,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(
          playerCenter,
          lightRadius,
          const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          const [0.0, 0.65, 1.0],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) =>
      oldDelegate.playerCenter != playerCenter ||
      oldDelegate.lightRadiusInCells != lightRadiusInCells ||
      oldDelegate.revealProgress != revealProgress ||
      oldDelegate.rememberedVeil != rememberedVeil ||
      oldDelegate.hiddenVeil != hiddenVeil ||
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.rememberedCells.length != rememberedCells.length ||
      oldDelegate.destinationGlow != destinationGlow;
}

/// The destination's show-through glow under a cave veil (A2).
class FogDestinationGlow {
  const FogDestinationGlow({
    required this.center,
    required this.radiusInCells,
    required this.strength,
  });

  /// Pixel center of the destination cell.
  final Offset center;

  final double radiusInCells;

  /// 0..1 — how much of the veil the glow lifts at its brightest point.
  final double strength;

  @override
  bool operator ==(Object other) =>
      other is FogDestinationGlow &&
      other.center == center &&
      other.radiusInCells == radiusInCells &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(center, radiusInCells, strength);
}
