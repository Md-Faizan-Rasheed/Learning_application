import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/ghost/ghost_player.dart';
import 'package:islamic_game/features/seerah_maze/logic/ghost/ghost_recorder.dart';
import 'package:islamic_game/features/seerah_maze/models/ghost_sample.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';

void main() {
  group('GhostSample JSON', () {
    test('round-trips through toJson/fromJson', () {
      const sample = GhostSample(elapsed: Duration(milliseconds: 1234), cell: MazeCoord(2, 5));

      expect(GhostSample.fromJson(sample.toJson()), sample);
    });

    test('fromJson rejects malformed input instead of throwing', () {
      expect(GhostSample.fromJson('not a list'), isNull);
      expect(GhostSample.fromJson([1, 2]), isNull); // wrong length
      expect(GhostSample.fromJson([1.5, 2, 3]), isNull); // non-int elapsed
      expect(GhostSample.fromJson(['a', 2, 3]), isNull);
    });
  });

  group('GhostRecorder', () {
    test('records a sample for each distinct cell', () {
      final recorder = GhostRecorder();

      recorder.record(elapsed: Duration.zero, cell: const MazeCoord(0, 0));
      recorder.record(elapsed: const Duration(milliseconds: 500), cell: const MazeCoord(0, 1));

      expect(recorder.samples, [
        const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
        const GhostSample(elapsed: Duration(milliseconds: 500), cell: MazeCoord(0, 1)),
      ]);
    });

    test('skips a redundant sample at the same cell as the last one', () {
      final recorder = GhostRecorder();
      recorder.record(elapsed: Duration.zero, cell: const MazeCoord(0, 0));

      recorder.record(elapsed: const Duration(milliseconds: 100), cell: const MazeCoord(0, 0));

      expect(recorder.samples, hasLength(1));
    });

    test('reset clears everything for a fresh playthrough', () {
      final recorder = GhostRecorder();
      recorder.record(elapsed: Duration.zero, cell: const MazeCoord(0, 0));

      recorder.reset();

      expect(recorder.samples, isEmpty);
    });
  });

  group('GhostPlayer.positionAt', () {
    final samples = [
      const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
      const GhostSample(elapsed: Duration(milliseconds: 1000), cell: MazeCoord(0, 1)),
      const GhostSample(elapsed: Duration(milliseconds: 2500), cell: MazeCoord(0, 2)),
    ];

    test('is a step function: holds the last reached cell until the next sample', () {
      final ghost = GhostPlayer(samples: samples);

      expect(ghost.positionAt(Duration.zero), const MazeCoord(0, 0));
      expect(ghost.positionAt(const Duration(milliseconds: 500)), const MazeCoord(0, 0));
      expect(ghost.positionAt(const Duration(milliseconds: 1000)), const MazeCoord(0, 1));
      expect(ghost.positionAt(const Duration(milliseconds: 2000)), const MazeCoord(0, 1));
      expect(ghost.positionAt(const Duration(milliseconds: 2500)), const MazeCoord(0, 2));
    });

    test('is null before the run starts or after it ends', () {
      final ghost = GhostPlayer(samples: samples);

      expect(ghost.positionAt(const Duration(milliseconds: -1)), isNull);
      expect(ghost.positionAt(const Duration(milliseconds: 2501)), isNull);
    });

    test('an empty ghost always returns null', () {
      final ghost = GhostPlayer(samples: const []);

      expect(ghost.positionAt(Duration.zero), isNull);
      expect(ghost.isEmpty, isTrue);
    });

    test('totalElapsed is the last sample\'s elapsed time', () {
      final ghost = GhostPlayer(samples: samples);

      expect(ghost.totalElapsed, const Duration(milliseconds: 2500));
    });

    test('is a pure function — same instant, same cell', () {
      final ghost = GhostPlayer(samples: samples);
      const at = Duration(milliseconds: 1750);

      expect(ghost.positionAt(at), ghost.positionAt(at));
    });
  });

  group('GhostPlayer.elapsedToReach', () {
    final samples = [
      const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
      const GhostSample(elapsed: Duration(milliseconds: 1000), cell: MazeCoord(0, 1)),
      const GhostSample(elapsed: Duration(milliseconds: 2500), cell: MazeCoord(0, 2)),
    ];

    test('returns the recorded time the ghost first reached that cell', () {
      final ghost = GhostPlayer(samples: samples);

      expect(ghost.elapsedToReach(const MazeCoord(0, 1)), const Duration(milliseconds: 1000));
    });

    test('returns null for a cell the ghost never visited', () {
      final ghost = GhostPlayer(samples: samples);

      expect(ghost.elapsedToReach(const MazeCoord(5, 5)), isNull);
    });
  });

  group('end-to-end: recorder -> player replays the exact same run', () {
    test('a recorded run, played back through GhostPlayer, matches step for step', () {
      final recorder = GhostRecorder();
      final moves = [
        const MazeCoord(0, 0),
        const MazeCoord(0, 1),
        const MazeCoord(1, 1),
        const MazeCoord(1, 2),
      ];
      for (var i = 0; i < moves.length; i++) {
        recorder.record(elapsed: Duration(milliseconds: i * 300), cell: moves[i]);
      }

      final ghost = GhostPlayer(samples: recorder.samples);

      for (var i = 0; i < moves.length; i++) {
        expect(ghost.positionAt(Duration(milliseconds: i * 300)), moves[i]);
      }
    });
  });
}
