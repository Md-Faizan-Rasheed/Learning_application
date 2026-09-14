import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/pad_scatter.dart';

/// Two squares of side [padSize] centered at [a]/[b] overlap unless they're
/// separated by at least [padSize] along the x-axis OR the y-axis — the
/// same axis-aligned check pad_scatter.dart itself uses (a plain Euclidean
/// distance check would wrongly pass a diagonal placement that still
/// overlaps).
bool _overlaps(Offset a, Offset b, double padSize) {
  final dx = (a.dx - b.dx).abs();
  final dy = (a.dy - b.dy).abs();
  return dx < padSize && dy < padSize;
}

void main() {
  group('pad_scatter no-overlap guarantee', () {
    // A small phone (portrait) and a tablet (landscape) water-area size,
    // matching the acceptance criteria's explicit "check both" requirement.
    const smallPhone = Size(296, 220); // ~320px-wide phone minus padding
    const tablet = Size(900, 380);

    for (final area in [smallPhone, tablet]) {
      for (final count in [5, 6, 7]) {
        test('$count pads never overlap on a ${area.width}x${area.height} area', () {
          final padSize = padSizeFor(count, area);
          final anchors = scatterAnchors(
            count: count,
            area: area,
            padSize: padSize,
            seed: count * 97 + area.width.round(),
          );

          expect(anchors.length, count);
          for (var i = 0; i < anchors.length; i++) {
            for (var j = i + 1; j < anchors.length; j++) {
              expect(_overlaps(anchors[i], anchors[j], padSize), isFalse,
                  reason: 'pads $i and $j overlap at $count on $area');
            }
          }
        });
      }
    }

    test('every anchor stays within the pad half-size of the area bounds', () {
      const area = Size(296, 220);
      const count = 7;
      final padSize = padSizeFor(count, area);
      final anchors = scatterAnchors(count: count, area: area, padSize: padSize, seed: 42);

      for (final a in anchors) {
        expect(a.dx, inInclusiveRange(0, area.width));
        expect(a.dy, inInclusiveRange(0, area.height));
      }
    });

    test('pad size shrinks as the batch grows, but never below the 48px minimum tap target',
        () {
      const area = Size(296, 500);
      final five = padSizeFor(5, area);
      final seven = padSizeFor(7, area);
      expect(seven, lessThanOrEqualTo(five));
      expect(seven, greaterThanOrEqualTo(48));
    });

    test('holds across many seeds and sizes, not just the ones picked above', () {
      final sizes = [
        const Size(280, 200), // the tightest realistic phone case
        const Size(360, 260),
        const Size(600, 320),
        const Size(1024, 420), // large tablet landscape
      ];
      for (final area in sizes) {
        for (final count in [5, 6, 7]) {
          final padSize = padSizeFor(count, area);
          for (var seed = 0; seed < 25; seed++) {
            final anchors = scatterAnchors(count: count, area: area, padSize: padSize, seed: seed);
            for (var i = 0; i < anchors.length; i++) {
              for (var j = i + 1; j < anchors.length; j++) {
                expect(_overlaps(anchors[i], anchors[j], padSize), isFalse,
                    reason: 'seed $seed, count $count, area $area: pads $i/$j overlap');
              }
            }
          }
        }
      }
    });
  });
}
