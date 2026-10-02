import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_environment.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_intro_scene.dart';

void main() {
  test('every environment theme maps to one of the three named motifs', () {
    for (final id in MazeEnvironmentId.values) {
      expect(MazeIntroSceneMotif.values, contains(mazeIntroSceneMotifFor(id)));
    }
  });

  test('both cave-ish/night themes use the stars motif', () {
    expect(mazeIntroSceneMotifFor(MazeEnvironmentId.desertNightStars),
        MazeIntroSceneMotif.starsAppearing);
    expect(mazeIntroSceneMotifFor(MazeEnvironmentId.rockyCave), MazeIntroSceneMotif.starsAppearing);
  });

  test('the caravan theme uses the caravan-crossing motif', () {
    expect(mazeIntroSceneMotifFor(MazeEnvironmentId.caravanSunset),
        MazeIntroSceneMotif.caravanCrossing);
  });

  test('daytime/dawn themes use the sun-rising motif', () {
    for (final id in [
      MazeEnvironmentId.makkahDawn,
      MazeEnvironmentId.desertDay,
      MazeEnvironmentId.madinahOasis,
    ]) {
      expect(mazeIntroSceneMotifFor(id), MazeIntroSceneMotif.sunRising);
    }
  });

  test('is a pure, deterministic lookup', () {
    for (final id in MazeEnvironmentId.values) {
      expect(mazeIntroSceneMotifFor(id), mazeIntroSceneMotifFor(id));
    }
  });
}
