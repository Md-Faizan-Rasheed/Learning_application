import '../../models/maze_cell.dart';
import '../../models/maze_direction.dart';
import '../maze_generator.dart';

/// One linked pair of tents. [index] is what the painter turns into a
/// glow color *and* a distinct pip count, so two pairs on the same board
/// are tellable apart without relying on hue.
class MazeTeleportPair {
  const MazeTeleportPair({required this.a, required this.b, required this.index});

  final MazeCoord a;
  final MazeCoord b;
  final int index;

  /// The other end of this pair, or null if [coord] isn't part of it.
  MazeCoord? partnerOf(MazeCoord coord) {
    if (coord == a) return b;
    if (coord == b) return a;
    return null;
  }

  bool contains(MazeCoord coord) => coord == a || coord == b;

  @override
  bool operator ==(Object other) =>
      other is MazeTeleportPair && other.a == a && other.b == b && other.index == index;

  @override
  int get hashCode => Object.hash(a, b, index);

  @override
  String toString() => 'MazeTeleportPair($a <-> $b)';
}

/// A5 — the tents on one level, plus the cooldown that stops them firing
/// repeatedly.
///
/// Ping-pong is prevented *structurally* rather than by the timer:
/// [partnerFor] only fires for a tent the player **walked** onto, never
/// for one they **arrived** on, so a jump can't immediately bounce back.
/// The cooldown on top of that is purely so a player standing next to a
/// tent can't step on and off to spam the effect.
///
/// Because the cooldown only ever *delays* a jump and never permanently
/// withholds one, it cannot make a level unsolvable — which is why the
/// pathfinder and [wouldBeTrivialShortcut] both reason about tents as
/// always-active, and only the live game consults the timer.
class TeleportNetwork {
  TeleportNetwork({required List<MazeTeleportPair> pairs, this.cooldown = Duration.zero})
      : pairs = List.unmodifiable(pairs);

  factory TeleportNetwork.none() => TeleportNetwork(pairs: const []);

  final List<MazeTeleportPair> pairs;
  final Duration cooldown;

  Duration _cooldownRemaining = Duration.zero;

  bool get isEmpty => pairs.isEmpty;
  bool get isOnCooldown => _cooldownRemaining > Duration.zero;

  /// Every cell holding a tent, for the painter.
  Set<MazeCoord> get tentCells => {
        for (final pair in pairs) ...[pair.a, pair.b],
      };

  MazeTeleportPair? pairAt(MazeCoord coord) {
    for (final pair in pairs) {
      if (pair.contains(coord)) return pair;
    }
    return null;
  }

  /// Where a tent at [coord] sends the player, ignoring the cooldown —
  /// this is the view the pathfinder and the validator take.
  MazeCoord? partnerFor(MazeCoord coord) => pairAt(coord)?.partnerOf(coord);

  /// The live-game version: null while the network is cooling down, so the
  /// player just stands on the tent instead of jumping.
  MazeCoord? activePartnerFor(MazeCoord coord) {
    if (isOnCooldown) return null;
    return partnerFor(coord);
  }

  /// Call right after a jump actually happens.
  void startCooldown() => _cooldownRemaining = cooldown;

  /// Driven by the same tick as the level timer, so it pauses with the game.
  void tick(Duration delta) {
    if (_cooldownRemaining == Duration.zero) return;
    final next = _cooldownRemaining - delta;
    _cooldownRemaining = next.isNegative ? Duration.zero : next;
  }

  void reset() => _cooldownRemaining = Duration.zero;

  // ---- Placement ----

  /// Picks [pairCount] tent pairs deterministically, keeping only pairs
  /// that don't turn the level into a trivial skip.
  ///
  /// Candidates are dead-end cells in row-major order — the same cells
  /// stars like, which makes a tent a thing you find off the main route
  /// rather than something sitting in your way. No RNG, so a level's tents
  /// are fixed by its seed, and [attemptCap] bounds the work so placement
  /// stays cheap even on the 16x16 finale.
  static TeleportNetwork place({
    required MazeGenerationResult maze,
    required int solutionLength,
    required int pairCount,
    required double minShortcutFraction,
    Duration cooldown = Duration.zero,
    Set<MazeCoord> reserved = const {},
    int attemptCap = 120,
  }) {
    if (pairCount < 1) return TeleportNetwork.none();

    final candidates = _candidateCells(maze: maze, reserved: reserved);
    if (candidates.length < 2) return TeleportNetwork.none();

    final accepted = <MazeTeleportPair>[];
    final used = <MazeCoord>{};
    var attempts = 0;

    for (var index = 0; index < pairCount; index++) {
      MazeTeleportPair? chosen;
      outer:
      for (var i = 0; i < candidates.length; i++) {
        if (used.contains(candidates[i])) continue;
        for (var j = i + 1; j < candidates.length; j++) {
          if (used.contains(candidates[j])) continue;
          if (attempts++ > attemptCap) break outer;

          final candidate = MazeTeleportPair(
            a: candidates[i],
            b: candidates[j],
            index: index,
          );
          final trial = TeleportNetwork(pairs: [...accepted, candidate]);
          if (trial.wouldBeTrivialShortcut(
            maze: maze,
            solutionLength: solutionLength,
            minShortcutFraction: minShortcutFraction,
          )) {
            continue;
          }
          chosen = candidate;
          break outer;
        }
      }
      if (chosen == null) break;
      accepted.add(chosen);
      used
        ..add(chosen.a)
        ..add(chosen.b);
    }

    return TeleportNetwork(pairs: accepted, cooldown: cooldown);
  }

  /// Whether these tents cut the journey shorter than the level is willing
  /// to allow — the spec's "never trivially skippable" rule, measured as a
  /// fraction of the original (tent-free) solution length.
  bool wouldBeTrivialShortcut({
    required MazeGenerationResult maze,
    required int solutionLength,
    required double minShortcutFraction,
  }) {
    if (solutionLength <= 0) return false;
    final withTents = _movesToDestination(maze);
    if (withTents < 0) return true; // sealed the goal off entirely
    return withTents < solutionLength * minShortcutFraction;
  }

  /// Shortest number of moves from start to destination with these tents
  /// active (and no other mechanic in play), or -1 if unreachable. Kept
  /// local rather than going through MazeSolver so placement has no
  /// dependency on the movement-rules layer that consumes it.
  int _movesToDestination(MazeGenerationResult maze) {
    final distance = <MazeCoord, int>{maze.start: 0};
    final queue = <MazeCoord>[maze.start];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      final steps = distance[current]!;
      if (current == maze.destination) return steps;

      for (final direction in maze.cellAt(current).openDirections) {
        var next = MazeCoord(
          current.row + direction.deltaRow,
          current.col + direction.deltaCol,
        );
        if (!maze.inBounds(next)) continue;
        // Walking onto a tent carries you straight through to its partner.
        next = partnerFor(next) ?? next;
        if (distance.containsKey(next)) continue;
        distance[next] = steps + 1;
        queue.add(next);
      }
    }
    return -1;
  }

  /// Dead ends, excluding the start, destination, stars and anything the
  /// caller has already claimed (keys, sand, arrows).
  static List<MazeCoord> _candidateCells({
    required MazeGenerationResult maze,
    required Set<MazeCoord> reserved,
  }) {
    final result = <MazeCoord>[];
    for (var row = 0; row < maze.size; row++) {
      for (var col = 0; col < maze.size; col++) {
        final coord = MazeCoord(row, col);
        if (coord == maze.start || coord == maze.destination) continue;
        if (reserved.contains(coord) || maze.starCoords.contains(coord)) continue;
        if (maze.cellAt(coord).openDirections.length != 1) continue;
        result.add(coord);
      }
    }
    return result;
  }
}
