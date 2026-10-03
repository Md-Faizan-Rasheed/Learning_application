import '../../models/ghost_sample.dart';
import '../../models/maze_cell.dart';

/// C1 — replays a previously recorded run against the live game clock.
///
/// Wraps a fixed, already-recorded [samples] list — nothing here mutates
/// over the ghost's lifetime, so [positionAt] and [elapsedToReach] are
/// pure functions of their argument, directly assertable and safe to call
/// every frame from a painter with no risk of drift.
class GhostPlayer {
  GhostPlayer({required List<GhostSample> samples}) : samples = List.unmodifiable(samples);

  final List<GhostSample> samples;

  bool get isEmpty => samples.isEmpty;

  Duration get totalElapsed => samples.isEmpty ? Duration.zero : samples.last.elapsed;

  /// Where the ghost was at [elapsed] into the level — the last sample
  /// whose own elapsed time is at or before [elapsed] (a step function:
  /// the ghost "snaps" from cell to cell exactly when the real run did,
  /// rather than sliding smoothly between them, since a maze move is
  /// itself a discrete step). Null before the first sample, or once
  /// [elapsed] exceeds the whole recorded run.
  MazeCoord? positionAt(Duration elapsed) {
    if (samples.isEmpty || elapsed < samples.first.elapsed) return null;
    if (elapsed > samples.last.elapsed) return null;
    MazeCoord? result;
    for (final sample in samples) {
      if (sample.elapsed > elapsed) break;
      result = sample.cell;
    }
    return result;
  }

  /// How long the recorded run took to first reach [cell], or null if it
  /// never visited that cell at all — the HUD's delta timer compares this
  /// against the live player's own elapsed time at the same cell.
  Duration? elapsedToReach(MazeCoord cell) {
    for (final sample in samples) {
      if (sample.cell == cell) return sample.elapsed;
    }
    return null;
  }
}
