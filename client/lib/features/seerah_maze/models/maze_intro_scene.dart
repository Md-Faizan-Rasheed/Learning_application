import 'maze_environment.dart';

/// B3 — which procedural animated scene plays behind a level's story
/// card. The spec names three example motifs (sun rising, caravan
/// crossing, stars appearing); rather than inventing a fourth for each
/// of the 6 environment themes, every theme maps onto whichever of the
/// three best matches its own time-of-day/setting.
enum MazeIntroSceneMotif { sunRising, caravanCrossing, starsAppearing }

MazeIntroSceneMotif mazeIntroSceneMotifFor(MazeEnvironmentId environmentId) =>
    switch (environmentId) {
      MazeEnvironmentId.makkahDawn => MazeIntroSceneMotif.sunRising,
      MazeEnvironmentId.desertDay => MazeIntroSceneMotif.sunRising,
      MazeEnvironmentId.madinahOasis => MazeIntroSceneMotif.sunRising,
      MazeEnvironmentId.caravanSunset => MazeIntroSceneMotif.caravanCrossing,
      MazeEnvironmentId.desertNightStars => MazeIntroSceneMotif.starsAppearing,
      MazeEnvironmentId.rockyCave => MazeIntroSceneMotif.starsAppearing,
    };
