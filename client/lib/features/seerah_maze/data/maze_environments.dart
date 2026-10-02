import '../models/maze_environment.dart';

/// Which of the 6 named atmospheres (B2) each level uses — grounded in
/// that level's own destinationKind and character/destination pairing
/// (data/maze_levels.dart), not picked arbitrarily:
///
///  1. Abdul Muttalib -> the Ka'bah: dawn over Makkah, the story's opening.
///  2. Halimah -> Makkah: the Bedouin desert of her clan.
///  3. Abu Talib's caravan -> Busra: the first trade journey, sunset road.
///  4. Khadija's caravan -> the trade route: the same road again.
///  5. The Prophet ﷺ -> Cave Hira: bare rock.
///  6. The believers -> Dar al-Arqam: back in Makkah, the dawn palette
///     returns for the city itself rather than a new one.
///  7. Abu Bakr -> Cave Thawr: bare rock again.
///  8. The Hijrah -> Madinah: arrival at the oasis city.
///  9. The Muslims -> Badr: the pre-dawn march before the battle.
/// 10. Bilal -> the Ka'bah: the return, full circle back to where it began.
const Map<int, MazeEnvironmentId> _kLevelEnvironments = {
  1: MazeEnvironmentId.makkahDawn,
  2: MazeEnvironmentId.desertDay,
  3: MazeEnvironmentId.caravanSunset,
  4: MazeEnvironmentId.caravanSunset,
  5: MazeEnvironmentId.rockyCave,
  6: MazeEnvironmentId.makkahDawn,
  7: MazeEnvironmentId.rockyCave,
  8: MazeEnvironmentId.madinahOasis,
  9: MazeEnvironmentId.desertNightStars,
  10: MazeEnvironmentId.makkahDawn,
};

/// The environment theme for [levelId]. Falls back to [MazeEnvironmentId
/// .makkahDawn] for any id this map doesn't cover — a future level added
/// without updating this map gets a sensible default atmosphere rather
/// than a lookup crash, unlike data/maze_chapters.dart's intentionally
/// strict [mazeChapterFor] (a missing chapter is a real data bug to catch
/// immediately; a missing environment is only a missed decoration).
MazeEnvironmentTheme mazeEnvironmentFor(int levelId) {
  final id = _kLevelEnvironments[levelId] ?? MazeEnvironmentId.makkahDawn;
  return kMazeEnvironmentThemes[id]!;
}
