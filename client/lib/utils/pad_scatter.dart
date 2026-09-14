import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Scales with the water container's own measured size (never a fixed
/// pixel value) and shrinks as more cards need to fit, leaving enough
/// spare room for [scatterAnchors] to actually find non-overlapping random
/// spots instead of falling back to a grid cell most of the time.
double padSizeFor(int count, Size area) {
  final base = math.min(area.width, area.height);
  final divisor = count <= 5 ? 3.2 : (count == 6 ? 3.6 : 4.0);
  return (base / divisor).clamp(56.0, 130.0);
}

const _gap = 8.0;

/// Two pads (treated as [padSize]-side squares) don't overlap iff they're
/// separated by at least [padSize] plus a small gap along the x-axis OR
/// the y-axis — a plain Euclidean-distance check would wrongly allow a
/// diagonal placement to overlap, since two squares exactly one side
/// -length apart on the diagonal still collide.
bool _isClear(Offset p, List<Offset> placed, double padSize) {
  final clearance = padSize + _gap;
  return placed.every(
      (a) => (a.dx - p.dx).abs() >= clearance || (a.dy - p.dy).abs() >= clearance);
}

/// Places [count] cards within [area] with a guarantee that none overlap.
///
/// Tries a fully organic random scatter first (each card rejection-sampled
/// against every already-placed one) — this is what makes the layout not
/// read as a grid when there's enough room. If even one card can't find a
/// free spot within a bounded number of attempts, the *whole* round falls
/// back to a stratified grid with jitter strictly bounded inside each
/// card's own cell (so it can never overlap a neighbor by construction),
/// rather than mixing the two per-card — a hybrid like that is what
/// previously let an unguarded fallback land on top of an already-placed
/// random card. On a small screen with a full 7-card round there may not
/// be enough free room for the organic pass to succeed, and it reads a
/// little more regular as a result — an inherent space tradeoff, not a
/// bug, and still guaranteed overlap-free either way.
List<Offset> scatterAnchors({
  required int count,
  required Size area,
  required double padSize,
  required int seed,
}) {
  if (count == 0) return const [];
  final organic = _tryOrganicScatter(count: count, area: area, padSize: padSize, seed: seed);
  return organic ?? _jitteredGridFallback(count: count, area: area, padSize: padSize, seed: seed);
}

List<Offset>? _tryOrganicScatter({
  required int count,
  required Size area,
  required double padSize,
  required int seed,
}) {
  final rng = math.Random(seed);
  final marginX = padSize / 2 + 6;
  final marginY = padSize / 2 + 6;
  final usableW = math.max(1.0, area.width - marginX * 2);
  final usableH = math.max(1.0, area.height - marginY * 2);

  final anchors = <Offset>[];
  for (var i = 0; i < count; i++) {
    Offset? candidate;
    for (var attempt = 0; attempt < 60; attempt++) {
      final p = Offset(
        marginX + rng.nextDouble() * usableW,
        marginY + rng.nextDouble() * usableH,
      );
      if (_isClear(p, anchors, padSize)) {
        candidate = p;
        break;
      }
    }
    if (candidate == null) return null; // not enough room — caller falls back
    anchors.add(candidate);
  }
  return anchors;
}

/// A stratified grid with jitter bounded to stay inside each card's own
/// cell — provably non-overlapping (no two cells' possible jitter ranges
/// can ever intersect), used only when [_tryOrganicScatter] can't find
/// room for a fully free-form layout.
List<Offset> _jitteredGridFallback({
  required int count,
  required Size area,
  required double padSize,
  required int seed,
}) {
  final rng = math.Random(seed);
  final cols = math.max(1, math.sqrt(count * area.width / area.height).ceil());
  final rows = (count / cols).ceil();
  final cellW = area.width / cols;
  final cellH = area.height / rows;
  final maxJitterX = math.max(0.0, cellW / 2 - padSize / 2 - 2);
  final maxJitterY = math.max(0.0, cellH / 2 - padSize / 2 - 2);

  return [
    for (var i = 0; i < count; i++)
      () {
        final col = i % cols;
        final row = i ~/ cols;
        final cx = col * cellW + cellW / 2 + (rng.nextDouble() * 2 - 1) * maxJitterX;
        final cy = row * cellH + cellH / 2 + (rng.nextDouble() * 2 - 1) * maxJitterY;
        return Offset(
          cx.clamp(padSize / 2, math.max(padSize / 2, area.width - padSize / 2)),
          cy.clamp(padSize / 2, math.max(padSize / 2, area.height - padSize / 2)),
        );
      }(),
  ];
}
