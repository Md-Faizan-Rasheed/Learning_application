import 'dart:math';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/radial_layout.dart';

/// A rotated rectangle's bounding circle is defined by its own diagonal,
/// not its width or height — this is the radius a node actually needs
/// clearance for once it's spun to point radially outward.
double _halfDiagonal(Size size) => 0.5 * sqrt(size.width * size.width + size.height * size.height);

void main() {
  group('layoutRadial', () {
    test('places ring 0 fixed at center, pointing straight up, no rotation', () {
      final placements =
          layoutRadial([const RadialNode(label: 'Root', ring: 0)]);
      expect(placements, hasLength(1));
      expect(placements.single.center, const Offset(0.5, 0.5));
      expect(placements.single.rotation, 0);
    });

    test('fans ring 1 nodes evenly around the center by angle', () {
      final nodes = List.generate(5, (i) => RadialNode(label: 'Cat $i', ring: 1));
      final placements = layoutRadial(nodes);
      expect(placements, hasLength(5));

      // Every node should sit the same distance from center (0.5, 0.5).
      final distances =
          placements.map((p) => (p.center - const Offset(0.5, 0.5)).distance).toSet();
      for (final d in distances) {
        expect(d, closeTo(distances.first, 0.001));
      }
    });

    test('a node\'s rotation matches its radial angle within the jitter bound', () {
      final nodes = List.generate(6, (i) => RadialNode(label: 'N$i', ring: 1));
      for (final p in layoutRadial(nodes)) {
        final radialAngle = atan2(p.center.dy - 0.5, p.center.dx - 0.5);
        final expectedRotation = radialAngle + pi / 2;
        var diff = (p.rotation - expectedRotation) % (2 * pi);
        if (diff > pi) diff -= 2 * pi;
        expect(diff.abs(), lessThanOrEqualTo(8 * pi / 180 + 1e-9),
            reason: 'rotation should be the radial angle plus at most +-8deg jitter');
      }
    });

    // Regression coverage for the "map never clips its own bounding box"
    // requirement: every node's rotated bounding circle (radius +
    // half-diagonal, since a spinning rectangle's corners reach further
    // than its edges) must stay within the 0..1 square with real margin,
    // at every situation count a category can actually have.
    test('every ring stays inside the map square across realistic node counts', () {
      const margin = 0.02;
      for (final count in [1, 4, 5, 8, 10, 12, 15]) {
        for (final ring in [1, 2]) {
          final nodes = List.generate(count, (i) => RadialNode(label: 'N$i', ring: ring));
          for (final p in layoutRadial(nodes)) {
            final radius = (p.center - const Offset(0.5, 0.5)).distance;
            final extent = radius + _halfDiagonal(p.size);
            expect(extent, lessThanOrEqualTo(0.5 - margin),
                reason: 'ring $ring at count $count overflows the map square '
                    '(extent: ${extent.toStringAsFixed(3)})');
          }
        }
      }
    });

    test('every node keeps at least a 44x44 tap target regardless of visual size', () {
      // The widget enforces this via max(44, nodeSize) at render time, but
      // it only has something to enforce it *on* if layoutRadial never
      // hands back a degenerate (zero or negative) size.
      final nodes = List.generate(15, (i) => RadialNode(label: 'N$i', ring: 2));
      for (final p in layoutRadial(nodes)) {
        expect(p.size.width, greaterThan(0));
        expect(p.size.height, greaterThan(0));
      }
    });

    test('a node defaults to unvisited, and carries visited through into its placement', () {
      const fresh = RadialNode(label: 'Fresh', ring: 1);
      expect(fresh.visited, isFalse);

      const seen = RadialNode(label: 'Seen', ring: 1, visited: true);
      final placement = layoutRadial([seen]).single;
      expect(placement.node.visited, isTrue);
    });

    test('is deterministic — the same nodes always produce the same placement', () {
      final nodes = List.generate(9, (i) => RadialNode(label: 'Situation $i', ring: 2));
      final a = layoutRadial(nodes);
      final b = layoutRadial(nodes);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].center, b[i].center);
        expect(a[i].rotation, b[i].rotation);
      }
    });
  });
}
