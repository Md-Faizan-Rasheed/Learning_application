import '../../models/ghost_sample.dart';
import '../../models/maze_cell.dart';

/// C1 — records a run as it happens, one [GhostSample] per cell visited.
/// Deliberately dumb: it has no idea what a move, a slide, or a teleport
/// is — the caller (MazeGameScreen) just calls [record] with the player's
/// current cell and elapsed time after anything that could have changed
/// position, so the ghost reproduces the run exactly regardless of which
/// mechanics caused it.
class GhostRecorder {
  final List<GhostSample> _samples = [];

  List<GhostSample> get samples => List.unmodifiable(_samples);

  /// Appends a sample, skipping a cell that's identical to the last one
  /// recorded (standing still, or a move that didn't change position) —
  /// no value in replaying a run with redundant waypoints.
  void record({required Duration elapsed, required MazeCoord cell}) {
    if (_samples.isNotEmpty && _samples.last.cell == cell) return;
    _samples.add(GhostSample(elapsed: elapsed, cell: cell));
  }

  void reset() => _samples.clear();
}
