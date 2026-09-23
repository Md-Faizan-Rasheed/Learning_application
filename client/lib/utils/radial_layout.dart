import 'dart:math';
import 'dart:ui' show Offset, Size;

/// One node in a radial map — which concentric ring it belongs to (0 =
/// center, 1 = inner ring, 2 = outer ring), its label, and what tapping it
/// does. `onTap == null` renders as a non-interactive, purely decorative
/// node (used for the center anchor). Shared by "Find My Ayah"'s Explore
/// tab (a constellation — see `widgets/constellation_map.dart`) for both
/// its root screen (ring 0 = the app anchor, ring 1 = categories) and its
/// per-category sub-tree (ring 0 = the category anchor, ring 2 =
/// situations).
class RadialNode {
  const RadialNode({required this.label, required this.ring, this.onTap, this.visited = false});

  final String label;
  final int ring;
  final void Function()? onTap;

  /// Whether the user has already opened this node's card at least once —
  /// purely a rendering hint (a "this one already shines" state), never
  /// consulted by the layout math itself.
  final bool visited;
}

/// Where and how one node should actually be drawn, computed by
/// [layoutRadial]. All geometry is fractional (0..1) of the map's own
/// square drawing area, so the caller can lay this out at any size.
class RadialPlacement {
  const RadialPlacement({
    required this.node,
    required this.center,
    required this.rotation,
    required this.size,
  });

  final RadialNode node;

  /// Fractional center point (0..1, 0..1) within the map's square area.
  final Offset center;

  /// The node's own radial angle (pointing outward from the map center),
  /// plus a small jitter — a renderer is free to ignore this (a symmetric
  /// star glyph doesn't need orienting) or use it for a directional shape.
  final double rotation;

  /// Fractional (width, height) of the node's own drawing box, relative
  /// to the map's square side length.
  final Size size;
}

/// Ring 0 sits at dead center; rings 1 and 2 fan out from there. Values are
/// fractions of the map's square side, chosen so that
/// `radius + halfDiagonal(nodeSize)` stays within ~0.48 for every ring at
/// any node count — i.e. the whole map fits inside its own square with a
/// small margin, so a parent `Stack` never has to clip it. A rotated node's
/// bounding box is bigger than its own footprint (its corners swing out
/// further than its edges), so this uses the node's half-diagonal, not
/// half-width, as the extra radius it needs.
const Map<int, double> _kRingRadius = {0: 0.0, 1: 0.28, 2: 0.34};
const Map<int, Size> _kRingNodeSize = {
  0: Size(0.34, 0.34),
  1: Size(0.22, 0.22),
  2: Size(0.15, 0.15),
};

/// Lays out [nodes] into concentric rings by polar coordinates — never
/// hand-placed pixels, so the map regenerates cleanly for any node count
/// per ring (a category with 4 situations and one with 15 both just work,
/// denser rings simply pack their nodes tighter).
///
/// Deterministic: the same [nodes] list always produces the same
/// placements (the angular jitter is seeded from each ring's own content,
/// not `Random()`'s ambient seed), so rebuilding the widget never makes the
/// map visually jump around.
List<RadialPlacement> layoutRadial(List<RadialNode> nodes) {
  final byRing = <int, List<RadialNode>>{};
  for (final node in nodes) {
    byRing.putIfAbsent(node.ring, () => []).add(node);
  }

  final placements = <RadialPlacement>[];
  byRing.forEach((ring, ringNodes) {
    placements.addAll(_layoutRing(ring, ringNodes));
  });
  return placements;
}

List<RadialPlacement> _layoutRing(int ring, List<RadialNode> nodes) {
  final count = nodes.length;
  final baseRadius = _kRingRadius[ring] ?? 0.52;
  final baseSize = _kRingNodeSize[ring] ?? const Size(0.15, 0.15);

  // Busier outer rings (a category can have 4-15 situations) get a touch
  // more radius to spread the extra tap targets apart, and shrink their
  // nodes so the ring doesn't become one solid mass — some overlap at the
  // edges is intended, but nodes should still read as individual points,
  // not a blob. The radius bump is capped, and shrinking the nodes shrinks
  // their half-diagonal too, so even at the high end of a category's
  // situation count the ring still fits inside the containment margin
  // `_kRingRadius` was chosen for.
  final radius = ring == 0 ? 0.0 : (baseRadius + (count > 8 ? (count - 8) * 0.006 : 0)).clamp(0.0, 0.40);
  final sizeScale = count > 10 ? (10 / count).clamp(0.55, 1.0) : 1.0;
  final size = Size(baseSize.width * sizeScale, baseSize.height * sizeScale);

  // Seeded on the ring's own content (not wall-clock/ambient randomness) —
  // same nodes always produce the same jitter, so the map doesn't visually
  // shuffle itself on every rebuild.
  final seed = ring * 1000 + count * 31 + nodes.fold<int>(0, (acc, n) => acc + n.label.length);
  final rng = Random(seed);

  final result = <RadialPlacement>[];
  for (var i = 0; i < count; i++) {
    if (ring == 0) {
      // The single center node: fixed, no jitter — the map's clean anchor.
      result.add(RadialPlacement(node: nodes[i], center: const Offset(0.5, 0.5), rotation: 0, size: size));
      continue;
    }

    // Angle 0 points right, -pi/2 points up (screen y grows downward) —
    // the first node in ring 1/2 starts pointing straight up, the rest fan
    // out evenly around the full circle from there.
    final angle = -pi / 2 + (2 * pi * i / count);
    final jitterDeg = (rng.nextDouble() * 2 - 1) * 8; // +-8 degrees
    final jitter = jitterDeg * pi / 180;

    final center = Offset(0.5 + radius * cos(angle), 0.5 + radius * sin(angle));
    final rotation = angle + pi / 2 + jitter;

    result.add(RadialPlacement(node: nodes[i], center: center, rotation: rotation, size: size));
  }
  return result;
}
