import '../../models/maze_cell.dart';
import '../../models/maze_direction.dart';
import '../../models/maze_passage_edge.dart';

/// A7 — passages that periodically close and reopen.
///
/// Scope note: a toggle only ever *closes* a passage that is open in the
/// generated maze, never carves a new one. That keeps the live graph a
/// subset of the base maze (so the all-open state is exactly the Phase 1
/// maze), and it means the cached wall picture never has to be rebuilt —
/// a closed toggle is drawn by its own small dynamic layer instead, which
/// is cheaper than invalidating the picture every time one flips.
///
/// Each edge alternates on its own staggered phase, derived purely from
/// elapsed time with no stepping state, so the whole schedule is
/// reproducible and assertable — and it freezes with the game, since
/// [tick] is driven by the same clock as the level timer.
class ShiftingWalls {
  ShiftingWalls({
    required List<MazePassageEdge> edges,
    required this.interval,
    required this.warningLead,
  })  : assert(interval > warningLead, 'the warning has to fit inside the interval'),
        edges = List.unmodifiable(edges),
        _frozenClosed = null;

  /// A state frozen for analysis: exactly [closed] is shut, regardless of
  /// time. Used to check every combination of toggle states up front.
  ShiftingWalls.frozen({
    required List<MazePassageEdge> edges,
    required Set<MazePassageEdge> closed,
  })  : edges = List.unmodifiable(edges),
        interval = const Duration(seconds: 1),
        warningLead = Duration.zero,
        _frozenClosed = Set.unmodifiable(closed);

  factory ShiftingWalls.none() => ShiftingWalls.frozen(edges: const [], closed: const {});

  final List<MazePassageEdge> edges;

  /// How long a passage stays in one state before flipping.
  final Duration interval;

  /// How long before a flip the glow cue appears.
  final Duration warningLead;

  final Set<MazePassageEdge>? _frozenClosed;

  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;

  bool get isEmpty => edges.isEmpty;

  void tick(Duration delta) {
    if (_frozenClosed != null) return;
    _elapsed += delta;
  }

  void reset() => _elapsed = Duration.zero;

  /// Passages shut right now.
  Set<MazePassageEdge> get closedEdges {
    final frozen = _frozenClosed;
    if (frozen != null) return frozen;
    return {
      for (var i = 0; i < edges.length; i++)
        if (_isClosedAt(i, _elapsed)) edges[i],
    };
  }

  /// Passages about to flip, during their warning window only — the glow
  /// pulse the spec asks for before a change.
  Set<MazePassageEdge> get warningEdges {
    if (_frozenClosed != null) return const {};
    return {
      for (var i = 0; i < edges.length; i++)
        if (_isWarningAt(i, _elapsed)) edges[i],
    };
  }

  bool isClosed(MazePassageEdge edge) => closedEdges.contains(edge);

  /// Whether the passage leaving [from] in [direction] is shut right now.
  bool isClosedPassage(MazeCoord from, MazeDirection direction) {
    if (edges.isEmpty) return false;
    return closedEdges.contains(MazePassageEdge(from, direction));
  }

  /// Staggers each edge by a fraction of the interval so a level's toggles
  /// don't all flip in unison, which would read as the whole maze lurching.
  Duration _phaseFor(int index) => Duration(
        microseconds: (interval.inMicroseconds * index / (edges.length + 1)).round(),
      );

  bool _isClosedAt(int index, Duration elapsed) {
    final micros = elapsed.inMicroseconds + _phaseFor(index).inMicroseconds;
    // Alternating: odd intervals are the closed ones.
    return (micros ~/ interval.inMicroseconds).isOdd;
  }

  bool _isWarningAt(int index, Duration elapsed) {
    final micros = elapsed.inMicroseconds + _phaseFor(index).inMicroseconds;
    final intoInterval = micros % interval.inMicroseconds;
    return intoInterval >= interval.inMicroseconds - warningLead.inMicroseconds;
  }

  /// Every combination of open/closed across [edges] — `2^n` sets, which is
  /// what A7's "validate this for all toggle states" needs. Kept here
  /// rather than in the validator so the enumeration lives next to the
  /// thing being enumerated.
  static List<Set<MazePassageEdge>> allStates(List<MazePassageEdge> edges) {
    final states = <Set<MazePassageEdge>>[];
    final total = 1 << edges.length;
    for (var mask = 0; mask < total; mask++) {
      states.add({
        for (var i = 0; i < edges.length; i++)
          if ((mask & (1 << i)) != 0) edges[i],
      });
    }
    return states;
  }
}
