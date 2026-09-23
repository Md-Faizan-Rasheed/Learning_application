import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/radial_layout.dart';
import 'constellation_map.dart';
import 'constellation_sky_painter.dart';

/// The Explore tab's full hero image for "Find My Ayah" — a night sky
/// (see `constellation_sky_painter.dart`) with the category/situation
/// constellation drawn over it (see `constellation_map.dart`). Replaces
/// the old tree/canopy hero with the same [RadialNode] input, so neither
/// calling screen needed to change its layout logic — only which hero
/// widget it hands the nodes to.
///
/// Owns a single twinkle clock and hands the same phase to both the sky's
/// ambient stars and the constellation's own stars/lines, so the whole
/// scene reads as one sky rather than two independently-animated layers.
class ConstellationHero extends StatefulWidget {
  const ConstellationHero({super.key, required this.nodes});

  final List<RadialNode> nodes;

  @override
  State<ConstellationHero> createState() => _ConstellationHeroState();
}

class _ConstellationHeroState extends State<ConstellationHero> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    // Always runs; `build()` reads reduced-motion reactively and freezes
    // the phase it hands down to 0 rather than gating the controller
    // itself — same convention as this screen's water/scenery animations.
    _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, _) {
          final phase = reduceMotion ? 0.0 : _twinkle.value * 2 * math.pi;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: ConstellationSkyPainter(twinklePhase: phase))),
              Positioned.fill(child: ConstellationMap(nodes: widget.nodes, twinklePhase: phase)),
            ],
          );
        },
      ),
    );
  }
}
