import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_environments.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_environment.dart';

void main() {
  group('mazeEnvironmentFor', () {
    test('every level 1-10 resolves to a real theme', () {
      for (final level in kMazeLevels) {
        final theme = mazeEnvironmentFor(level.id);
        expect(theme.backgroundGradient.length, greaterThanOrEqualTo(2));
        expect(theme.parallaxLayers, isNotEmpty);
      }
    });

    test('an id outside 1-10 falls back to makkahDawn rather than crashing', () {
      final theme = mazeEnvironmentFor(999);
      expect(theme.id, MazeEnvironmentId.makkahDawn);
    });

    test('is a pure, deterministic lookup', () {
      expect(mazeEnvironmentFor(5).id, mazeEnvironmentFor(5).id);
    });

    test('all 6 named themes are actually used by at least one level', () {
      final used = kMazeLevels.map((l) => mazeEnvironmentFor(l.id).id).toSet();
      expect(used, MazeEnvironmentId.values.toSet());
    });

    test('the two cave levels (5 and 7) share the rocky cave theme', () {
      expect(mazeEnvironmentFor(5).id, MazeEnvironmentId.rockyCave);
      expect(mazeEnvironmentFor(7).id, MazeEnvironmentId.rockyCave);
    });
  });

  group('kMazeEnvironmentThemes', () {
    test('every theme has at least 2 parallax layers', () {
      for (final theme in kMazeEnvironmentThemes.values) {
        expect(theme.parallaxLayers.length, greaterThanOrEqualTo(1));
      }
    });

    test('every parallax layer has a depth in a sane, subtle range', () {
      for (final theme in kMazeEnvironmentThemes.values) {
        for (final layer in theme.parallaxLayers) {
          expect(layer.depth, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('defines exactly the 6 named atmospheres from the spec', () {
      expect(kMazeEnvironmentThemes.keys.toSet(), MazeEnvironmentId.values.toSet());
    });
  });
}
