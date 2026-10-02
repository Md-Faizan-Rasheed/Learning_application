import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../logic/environment/ambient_particle_field.dart';
import '../models/maze_environment.dart';

/// B2 — the backdrop behind the maze board: [layers]' parallax
/// silhouettes, then the ambient particle field on top. Sits in its own
/// layer behind everything the board itself draws, so it never affects
/// hit-testing or the board's own cached picture.
///
/// [parallaxShift] is the subtle, bounded horizontal offset driven by the
/// player's progress across the board (0..1) — multiplied by each layer's
/// own depth, so distant layers barely move and nother layer moves more,
/// but always within a few logical pixels. That's deliberately a tiny
/// fraction of the layer's own width, never enough to reveal a seam at
/// the horizontal wrap.
class EnvironmentPainter extends CustomPainter {
  const EnvironmentPainter({
    required this.layers,
    required this.particles,
    required this.parallaxShift,
  });

  final List<MazeParallaxLayer> layers;
  final List<AmbientParticle> particles;

  /// -1..1, typically driven by (playerX / mazeSize) * 2 - 1.
  final double parallaxShift;

  static const double _maxShiftPixels = 18;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      _paintLayer(canvas, size, layer);
    }
    _paintParticles(canvas, size);
  }

  void _paintLayer(Canvas canvas, Size size, MazeParallaxLayer layer) {
    final shiftX = parallaxShift * _maxShiftPixels * layer.depth;
    switch (layer.shape) {
      case MazeParallaxShape.ridge:
        _paintRidge(canvas, size, layer, shiftX);
      case MazeParallaxShape.palms:
        _paintPalms(canvas, size, layer, shiftX);
    }
  }

  /// A horizon silhouette whose jaggedness ranges from smooth dune curves
  /// (low) to angular rock peaks (high) — one shape renderer covering
  /// both, parameterized rather than duplicated.
  void _paintRidge(Canvas canvas, Size size, MazeParallaxLayer layer, double shiftX) {
    final baseline = size.height * (0.55 + layer.depth * 0.6);
    final amplitude = size.height * (0.05 + layer.jaggedness * 0.1);
    const segments = 7;
    final segmentWidth = size.width / segments;

    final path = Path()..moveTo(-segmentWidth + shiftX, size.height);
    path.lineTo(-segmentWidth + shiftX, baseline);
    for (var i = 0; i <= segments + 1; i++) {
      final x = -segmentWidth + i * segmentWidth + shiftX;
      // Deterministic per-segment height from a fixed trig combination —
      // no RNG, so the horizon never redraws differently frame to frame.
      final wave = math.sin(i * 1.7) * 0.6 + math.sin(i * 3.1 + 1) * 0.4;
      final y = baseline - amplitude * (layer.jaggedness > 0.5 ? wave.abs() : (wave + 1) / 2);
      if (layer.jaggedness > 0.5) {
        path.lineTo(x, y);
      } else {
        path.quadraticBezierTo(x - segmentWidth / 2, y, x, y);
      }
    }
    path.lineTo(size.width + segmentWidth, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = layer.color);
  }

  /// A row of simple palm silhouettes (trunk + a small frond fan) for the
  /// oasis theme — the one shape that isn't a horizon line.
  void _paintPalms(Canvas canvas, Size size, MazeParallaxLayer layer, double shiftX) {
    final baseline = size.height * (0.6 + layer.depth * 0.5);
    final paint = Paint()..color = layer.color;
    const count = 4;
    final spacing = size.width / count;

    for (var i = -1; i <= count; i++) {
      final x = i * spacing + spacing / 2 + shiftX;
      final trunkHeight = size.height * 0.16;
      final trunkWidth = size.width * 0.012;
      canvas.drawRect(
        Rect.fromLTWH(x - trunkWidth / 2, baseline - trunkHeight, trunkWidth, trunkHeight),
        paint,
      );
      // Three frond strokes fanning from the trunk top.
      final top = Offset(x, baseline - trunkHeight);
      for (final angle in [-0.9, -0.3, 0.3, 0.9]) {
        final frond = Offset(
          top.dx + math.cos(angle - math.pi / 2) * size.width * 0.035,
          top.dy + math.sin(angle - math.pi / 2) * size.width * 0.035,
        );
        canvas.drawLine(
          top,
          frond,
          Paint()
            ..color = layer.color
            ..strokeWidth = math.max(1, size.width * 0.006)
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    for (final particle in particles) {
      final center = Offset(particle.position.x * size.width, particle.position.y * size.height);
      canvas.drawCircle(
        center,
        particle.size,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: particle.opacity.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnvironmentPainter oldDelegate) =>
      oldDelegate.layers != layers ||
      oldDelegate.parallaxShift != parallaxShift ||
      oldDelegate.particles.length != particles.length ||
      !_sameParticles(oldDelegate.particles, particles);

  static bool _sameParticles(List<AmbientParticle> a, List<AmbientParticle> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].opacity != b[i].opacity || a[i].position != b[i].position) return false;
    }
    return true;
  }
}
