import '../../../../l10n/app_localizations.dart';
import '../../models/maze_achievement.dart';

/// D1 — title/description for one achievement, resolved live against the
/// active locale. Kept out of models/maze_achievement.dart itself for the
/// same reason mazeLevelTextFor is kept out of MazeLevel: the definitions
/// stay plain, locale-free data.
class MazeAchievementText {
  const MazeAchievementText({required this.title, required this.description});

  final String title;
  final String description;
}

MazeAchievementText mazeAchievementTextFor(AppLocalizations t, MazeAchievementId id) {
  switch (id) {
    case MazeAchievementId.firstSteps:
      return MazeAchievementText(
        title: t.mazeAchievementFirstStepsTitle,
        description: t.mazeAchievementFirstStepsDesc,
      );
    case MazeAchievementId.halfwayThere:
      return MazeAchievementText(
        title: t.mazeAchievementHalfwayThereTitle,
        description: t.mazeAchievementHalfwayThereDesc,
      );
    case MazeAchievementId.journeysEnd:
      return MazeAchievementText(
        title: t.mazeAchievementJourneysEndTitle,
        description: t.mazeAchievementJourneysEndDesc,
      );
    case MazeAchievementId.starCollector:
      return MazeAchievementText(
        title: t.mazeAchievementStarCollectorTitle,
        description: t.mazeAchievementStarCollectorDesc,
      );
    case MazeAchievementId.perfectCampaign:
      return MazeAchievementText(
        title: t.mazeAchievementPerfectCampaignTitle,
        description: t.mazeAchievementPerfectCampaignDesc,
      );
    case MazeAchievementId.seerahScholar:
      return MazeAchievementText(
        title: t.mazeAchievementSeerahScholarTitle,
        description: t.mazeAchievementSeerahScholarDesc,
      );
    case MazeAchievementId.noHintsMaster:
      return MazeAchievementText(
        title: t.mazeAchievementNoHintsMasterTitle,
        description: t.mazeAchievementNoHintsMasterDesc,
      );
    case MazeAchievementId.racingSpirit:
      return MazeAchievementText(
        title: t.mazeAchievementRacingSpiritTitle,
        description: t.mazeAchievementRacingSpiritDesc,
      );
    case MazeAchievementId.gettingStarted:
      return MazeAchievementText(
        title: t.mazeAchievementGettingStartedTitle,
        description: t.mazeAchievementGettingStartedDesc,
      );
    case MazeAchievementId.weekOfDevotion:
      return MazeAchievementText(
        title: t.mazeAchievementWeekOfDevotionTitle,
        description: t.mazeAchievementWeekOfDevotionDesc,
      );
    case MazeAchievementId.habitFormed:
      return MazeAchievementText(
        title: t.mazeAchievementHabitFormedTitle,
        description: t.mazeAchievementHabitFormedDesc,
      );
    case MazeAchievementId.enduranceRunner:
      return MazeAchievementText(
        title: t.mazeAchievementEnduranceRunnerTitle,
        description: t.mazeAchievementEnduranceRunnerDesc,
      );
    case MazeAchievementId.centuryClub:
      return MazeAchievementText(
        title: t.mazeAchievementCenturyClubTitle,
        description: t.mazeAchievementCenturyClubDesc,
      );
  }
}
