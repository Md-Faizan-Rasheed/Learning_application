import '../../data/daily_maze_repository.dart';
import '../../data/endless_run_repository.dart';
import '../../data/ghost_run_repository.dart';
import '../../data/maze_levels.dart';
import '../../data/maze_progress_repository.dart';
import '../../models/daily_maze_progress.dart';
import '../../models/endless_best_run.dart';
import '../../models/maze_achievement.dart';

/// D1/D2 — every achievement input except the campaign's own
/// [MazeProgress] — split out so a screen that already holds a live,
/// in-memory MazeProgress (level_select_screen.dart) can combine it with
/// this instead of pulling a second, separately-loaded (and therefore
/// easily stale) copy of it.
class MazeAchievementSideData {
  const MazeAchievementSideData({
    required this.daily,
    required this.endless,
    required this.ghostLevelsRecorded,
    required this.totalLevels,
  });

  final DailyMazeProgress daily;
  final EndlessBestRun endless;
  final int ghostLevelsRecorded;
  final int totalLevels;
}

Future<MazeAchievementSideData> loadMazeAchievementSideData({
  DailyMazeRepository dailyRepository = const DailyMazeRepository(),
  EndlessRunRepository endlessRepository = const EndlessRunRepository(),
  GhostRunRepository ghostRepository = const GhostRunRepository(),
}) async {
  final daily = await dailyRepository.load();
  final endless = await endlessRepository.load();

  var ghostLevelsRecorded = 0;
  for (final level in kMazeLevels) {
    final best = await ghostRepository.loadBest(level.id);
    if (best.isNotEmpty) ghostLevelsRecorded++;
  }

  return MazeAchievementSideData(
    daily: daily,
    endless: endless,
    ghostLevelsRecorded: ghostLevelsRecorded,
    totalLevels: kMazeLevels.length,
  );
}

/// D1 — pulls together every achievement input from its own existing
/// repository. No new storage: this just reads what C1-C4 and the
/// campaign already save. Each repository is injectable (same reason as
/// every other screen in this feature) so tests can substitute fakes
/// instead of touching real SharedPreferences.
Future<MazeAchievementInputs> loadMazeAchievementInputs({
  MazeProgressRepository progressRepository = const MazeProgressRepository(),
  DailyMazeRepository dailyRepository = const DailyMazeRepository(),
  EndlessRunRepository endlessRepository = const EndlessRunRepository(),
  GhostRunRepository ghostRepository = const GhostRunRepository(),
}) async {
  final progress = await progressRepository.load();
  final side = await loadMazeAchievementSideData(
    dailyRepository: dailyRepository,
    endlessRepository: endlessRepository,
    ghostRepository: ghostRepository,
  );

  return MazeAchievementInputs(
    progress: progress,
    daily: side.daily,
    endless: side.endless,
    ghostLevelsRecorded: side.ghostLevelsRecorded,
    totalLevels: side.totalLevels,
  );
}
