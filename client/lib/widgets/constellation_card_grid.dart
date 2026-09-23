import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../utils/radial_layout.dart';
import 'constellation_map.dart';
import 'constellation_sky_painter.dart';

/// Below this width, [ConstellationHero]'s radial layout either overlaps
/// or leaves excessive whitespace, so callers should show
/// [ConstellationCardGrid] instead. Matches the 600dp phone/tablet
/// threshold used elsewhere in this app.
const double kConstellationGridBreakpoint = 600;

/// The Explore tab's narrow-screen fallback: below 600dp, a radial
/// constellation either overlaps or leaves excessive whitespace, so this
/// collapses the same [RadialNode] list (minus the non-interactive ring-0
/// anchor, already shown by the screen's own AppHeader title) into a
/// scrollable 2-column grid of star "cards" — same night-sky colors and
/// visited/unvisited states as [ConstellationMap], connecting lines
/// dropped since a card grid has no "center" for them to radiate from.
class ConstellationCardGrid extends StatelessWidget {
  const ConstellationCardGrid({super.key, required this.nodes});

  final List<RadialNode> nodes;

  @override
  Widget build(BuildContext context) {
    final satellites = nodes.where((n) => n.ring != 0).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ConstellationSkyPainter.skyTop, ConstellationSkyPainter.skyBottom],
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: 1.05,
        ),
        itemCount: satellites.length,
        itemBuilder: (context, i) => _StarCard(node: satellites[i]),
      ),
    );
  }
}

class _StarCard extends StatefulWidget {
  const _StarCard({required this.node});

  final RadialNode node;

  @override
  State<_StarCard> createState() => _StarCardState();
}

class _StarCardState extends State<_StarCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.node.onTap == null) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final visited = widget.node.visited;
    final onTap = widget.node.onTap;
    final color = visited ? kStarGold : kStarDim;

    void handleTap() {
      if (onTap == null) return;
      SoundService.instance.playCorrect(pitch: 0.85);
      onTap();
    }

    return Semantics(
      button: onTap != null,
      label: '${widget.node.label}. ${visited ? 'Visited.' : 'Not yet explored.'}',
      child: GestureDetector(
        onTap: onTap == null ? null : handleTap,
        onTapDown: onTap == null ? null : (_) => _setPressed(true),
        onTapUp: onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: onTap == null ? null : () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: visited ? 0.06 : 0.03),
              border: Border.all(color: color.withValues(alpha: visited ? 0.55 : 0.35)),
              boxShadow: visited
                  ? [BoxShadow(color: kStarGold.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: 1)]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(30, 30),
                      painter: SparkleStarPainter(color: color, filled: visited, opacity: visited ? 1.0 : 0.7),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.node.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kStarCream,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (visited)
                  Positioned(
                    top: 8,
                    right: 8,
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
    );
  }
}
