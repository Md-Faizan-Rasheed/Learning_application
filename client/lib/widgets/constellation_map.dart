import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/radial_layout.dart';

/// The constellation's one consistent color family — category no longer
/// carries its own hue (there is no "gold means X, blue means Y" to
/// decode). Color only ever encodes a node's own state, and every color
/// difference is paired with a shape/fill difference too, so nothing here
/// depends on color alone.
const Color kStarCream = Color(0xFFF5F2E6);
const Color kStarGold = AppPalette.mutedGold;
const Color kStarDim = Color(0xFF5A5F7E);

/// Recreates the Explore tab's constellation: a bright anchor star at
/// center with categories (or situations, for the sub-tree) fanned around
/// it as linked stars, connected by fine gold lines. Ring/angle math is
/// entirely `radial_layout.dart`'s; this widget only decides how a ring
/// 0/1/2 node *looks*.
///
/// [twinklePhase] is owned by the caller (`ConstellationHero`) so the
/// ambient sky and every star here twinkle from one shared clock rather
/// than each rolling its own.
class ConstellationMap extends StatelessWidget {
  const ConstellationMap({super.key, required this.nodes, required this.twinklePhase});

  final List<RadialNode> nodes;
  final double twinklePhase;

  @override
  Widget build(BuildContext context) {
    final placements = layoutRadial(nodes);
    // Outer rings painted first (behind), inner rings last (on top) — same
    // stacking convention the leaf canopy this replaced used, so nearer
    // rings never sit beneath farther ones.
    final ordered = [...placements]..sort((a, b) => b.node.ring.compareTo(a.node.ring));

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final parentSize = Size(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConstellationLinesPainter(
                    placements: placements,
                    mapSide: side,
                    parentSize: parentSize,
                    phase: twinklePhase,
                  ),
                ),
              ),
              for (final placement in ordered)
                _ConstellationStar(
                  placement: placement,
                  mapSide: side,
                  parentSize: parentSize,
                  twinklePhase: twinklePhase,
                ),
            ],
          ),
        );
      },
    );
  }
}

Offset _toPixels(Offset fractional, Size mapSide, Size parentSize) => Offset(
      parentSize.width / 2 + (fractional.dx - 0.5) * mapSide.width,
      parentSize.height / 2 + (fractional.dy - 0.5) * mapSide.height,
    );

/// Purely decorative constellation art connecting a satellite back to the
/// center — never a claim about a relationship *between* two satellites
/// (Faith isn't "connected" to Trials by a line). Kept deliberately muted
/// so it never competes with the star/label content it's behind.
class _ConstellationLinesPainter extends CustomPainter {
  const _ConstellationLinesPainter({
    required this.placements,
    required this.mapSide,
    required this.parentSize,
    required this.phase,
  });

  final List<RadialPlacement> placements;
  final double mapSide;
  final Size parentSize;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    RadialPlacement? center;
    for (final p in placements) {
      if (p.node.ring == 0) center = p;
    }
    if (center == null) return;

    final mapSquare = Size(mapSide, mapSide);
    final centerPx = _toPixels(center.center, mapSquare, parentSize);

    for (final p in placements) {
      if (p.node.ring == 0) continue;
      final targetPx = _toPixels(p.center, mapSquare, parentSize);
      // A per-line phase offset derived from the target's own fixed
      // position, so lines don't all pulse in lockstep with each other.
      final seedPhase = (p.center.dx * 613 + p.center.dy * 397) % (2 * math.pi);
      final pulse = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(phase + seedPhase));
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          colors: [
            kStarGold.withValues(alpha: 0.32 * pulse),
            kStarGold.withValues(alpha: 0.06),
          ],
        ).createShader(Rect.fromPoints(centerPx, targetPx));
      canvas.drawLine(centerPx, targetPx, line);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationLinesPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.placements != placements;
}

class _ConstellationStar extends StatefulWidget {
  const _ConstellationStar({
    required this.placement,
    required this.mapSide,
    required this.parentSize,
    required this.twinklePhase,
  });

  final RadialPlacement placement;
  final double mapSide;
  final Size parentSize;
  final double twinklePhase;

  @override
  State<_ConstellationStar> createState() => _ConstellationStarState();
}

class _ConstellationStarState extends State<_ConstellationStar> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.placement.node.onTap == null) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.placement;
    final mapSquare = Size(widget.mapSide, widget.mapSide);
    final centerPx = _toPixels(p.center, mapSquare, widget.parentSize);

    final starW = p.size.width * widget.mapSide;
    final starH = p.size.height * widget.mapSide;
    final isAnchor = p.node.ring == 0;
    final visited = p.node.visited;

    // The glow is a purely decorative halo and is allowed to render far
    // bigger than the actual tap target (below) — it's wrapped in
    // IgnorePointer precisely so that visual bleed never steals taps
    // meant for a different, nearer star sitting underneath it.
    final glowRadius = math.max(starW, starH) * (isAnchor ? 1.9 : (visited ? 1.4 : 0.9));
    final tapSide = math.max(44.0, math.max(starW, starH) * 1.6);

    // State is never color alone: unvisited is a hollow outline (no
    // fill, no glow, no badge), visited is a solid fill with a glow and a
    // checkmark badge, and the anchor renders as an entirely different
    // glyph (an 8-point burst, not a 4-point sparkle) — hierarchy reads
    // by shape even for a color-blind reader or in a screenshot.
    final color = isAnchor || visited ? (isAnchor ? kStarCream : kStarGold) : kStarDim;

    final seedPhase = (p.center.dx * 971 + p.center.dy * 733) % (2 * math.pi);
    var twinkle = isAnchor
        ? 0.85 + 0.15 * math.sin(widget.twinklePhase * 0.6)
        : 0.55 + 0.45 * (0.5 + 0.5 * math.sin(widget.twinklePhase + seedPhase));
    if (_pressed) twinkle = 1.0; // a visible brighten on press, on top of scaling down

    final onTap = p.node.onTap;
    void handleTap() {
      if (onTap == null) return;
      // Softer/lower-pitched than the quiz "correct" chime this clip is
      // normally used for — reads as a gentle "select" tap here rather
      // than an answer being marked right, while reusing the one bundled
      // sound asset instead of sourcing a dedicated star-chime clip.
      SoundService.instance.playCorrect(pitch: 0.85);
      onTap();
    }

    final semanticsLabel = isAnchor
        ? p.node.label
        : '${p.node.label}. ${visited ? 'Visited.' : 'Not yet explored.'}';

    return Positioned(
      left: centerPx.dx - tapSide / 2,
      top: centerPx.dy - tapSide / 2,
      width: tapSide,
      height: tapSide,
      child: Semantics(
        button: onTap != null,
        label: semanticsLabel,
        child: GestureDetector(
          behavior: onTap == null ? HitTestBehavior.translucent : HitTestBehavior.opaque,
          onTap: onTap == null ? null : handleTap,
          onTapDown: onTap == null ? null : (_) => _setPressed(true),
          onTapUp: onTap == null ? null : (_) => _setPressed(false),
          onTapCancel: onTap == null ? null : () => _setPressed(false),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: AnimatedScale(
                  scale: _pressed ? 0.88 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    width: glowRadius * 2,
                    height: glowRadius * 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isAnchor || visited)
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color.withValues(alpha: (isAnchor ? 0.55 : 0.42) * twinkle),
                                  color.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        CustomPaint(
                          size: Size(starW, starH),
                          painter: SparkleStarPainter(
                            color: color,
                            points: isAnchor ? 8 : 4,
                            filled: isAnchor || visited,
                            opacity: isAnchor || visited
                                ? (0.7 + 0.3 * twinkle).clamp(0.0, 1.0)
                                : 0.6,
                          ),
                        ),
                        if (visited && !isAnchor)
                          Positioned(
                            bottom: glowRadius - starH * 0.3,
                            right: glowRadius - starW * 0.3,
                            child: Container(
                              width: 15,
                              height: 15,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kStarGold,
                                border: Border.all(color: const Color(0xFF14173A), width: 1.5),
                              ),
                              child: const Icon(Icons.check_rounded, size: 10, color: Color(0xFF14173A)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: tapSide / 2 + glowRadius * 0.5,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: math.max(76.0, starW * 2.6),
                    child: _StarLabel(
                      text: p.node.label,
                      maxFontSize: isAnchor ? 18 : (p.node.ring == 1 ? 14 : 12),
                      fontWeight: isAnchor ? FontWeight.w800 : (p.node.ring == 1 ? FontWeight.w700 : FontWeight.w600),
                      maxWidth: math.max(76.0, starW * 2.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An N-point path alternating outer/inner radius — 4 points (2N=8
/// vertices) reads as a classic "twinkle" sparkle for satellites, 8
/// points (2N=16 vertices) reads as a denser, more radiant burst for the
/// center anchor. [filled] false draws a hollow outline instead (the
/// "unvisited" state) so state never depends on color alone.
class SparkleStarPainter extends CustomPainter {
  const SparkleStarPainter({
    required this.color,
    this.points = 4,
    this.filled = true,
    this.opacity = 1.0,
  });

  final Color color;
  final int points;
  final bool filled;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = math.min(size.width, size.height) / 2;
    final inner = outer * (points > 4 ? 0.44 : 0.32);
    final vertices = points * 2;

    final path = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = i * math.pi / points - math.pi / 2;
      final r = i.isEven ? outer : inner;
      final point = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final paint = filled
        ? (Paint()..color = color.withValues(alpha: opacity))
        : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, outer * 0.14)
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: opacity));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparkleStarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.points != points ||
      oldDelegate.filled != filled ||
      oldDelegate.opacity != opacity;
}

/// Always a bright, uniform cream — text color never varies by category
/// or visited-state, so contrast against the night sky is guaranteed
/// regardless of what the star itself is doing. Hierarchy (center vs.
/// ring 1 vs. ring 2) reads through [maxFontSize]/[fontWeight] instead.
/// Shrinks to fit via [FittedBox], but only down to a floor size below
/// which it switches to a fixed-size, ellipsized label instead of
/// continuing to shrink into illegibility.
class _StarLabel extends StatelessWidget {
  const _StarLabel({
    required this.text,
    required this.maxFontSize,
    required this.fontWeight,
    required this.maxWidth,
  });

  static const double _kMinFontSize = 10.0;

  final String text;
  final double maxFontSize;
  final FontWeight fontWeight;
  final double maxWidth;

  TextStyle _style(double fontSize) => TextStyle(
        color: kStarCream,
        fontWeight: fontWeight,
        fontSize: fontSize,
        height: 1.05,
        shadows: const [Shadow(color: Color(0xCC0A1130), blurRadius: 3)],
      );

  @override
  Widget build(BuildContext context) {
    final minStyle = _style(_kMinFontSize);
    final painter = TextPainter(
      text: TextSpan(text: text, style: minStyle),
      maxLines: 2,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);

    if (painter.didExceedMaxLines) {
      return Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: minStyle,
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, textAlign: TextAlign.center, maxLines: 2, style: _style(maxFontSize)),
    );
  }
}
