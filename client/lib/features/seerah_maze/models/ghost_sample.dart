import 'maze_cell.dart';

/// C1 — one waypoint of a recorded run: the player was at [cell] by the
/// time [elapsed] had passed since the level started. A full run is a
/// list of these, oldest first, one per successful move (plus the start
/// cell at elapsed zero) — compact enough to persist as plain JSON and
/// simple enough to replay deterministically (see logic/ghost/).
class GhostSample {
  const GhostSample({required this.elapsed, required this.cell});

  final Duration elapsed;
  final MazeCoord cell;

  /// A 3-element [elapsedMs, row, col] array — chosen over a map so a
  /// run of dozens of samples stays small in SharedPreferences.
  List<Object> toJson() => [elapsed.inMilliseconds, cell.row, cell.col];

  /// Null on any malformed entry, so one corrupt sample invalidates the
  /// whole run (handled by the caller) rather than silently shifting
  /// every later lookup.
  static GhostSample? fromJson(Object? raw) {
    if (raw is! List || raw.length != 3) return null;
    final elapsedMs = raw[0];
    final row = raw[1];
    final col = raw[2];
    if (elapsedMs is! int || row is! int || col is! int) return null;
    return GhostSample(elapsed: Duration(milliseconds: elapsedMs), cell: MazeCoord(row, col));
  }

  @override
  bool operator ==(Object other) =>
      other is GhostSample && other.elapsed == elapsed && other.cell == cell;

  @override
  int get hashCode => Object.hash(elapsed, cell);

  @override
  String toString() => 'GhostSample(${elapsed.inMilliseconds}ms, $cell)';
}
