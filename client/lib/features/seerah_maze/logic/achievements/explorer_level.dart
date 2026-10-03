import '../../models/maze_achievement.dart';

/// D2 — the "Explorer Level" is a single account-wide number aggregating
/// everything the campaign, Daily, Endless and achievements already
/// track into one XP total, so progress scattered across every mode
/// reads as one continuous sense of growth. It is never itself stored:
/// recomputed live from [MazeAchievementInputs] every time it's shown,
/// so it can never drift out of sync with the stats it's built from.
int explorerXpFor(MazeAchievementInputs inputs) {
  final totalStars = inputs.progress.starsByLevel.values.fold(0, (a, b) => a + b);
  final xpFromStars = totalStars * 10;
  final xpFromFacts = inputs.progress.collectedFactLevelIds.length * 15;
  final xpFromNoHints = inputs.progress.noHintsClearedLevelIds.length * 20;
  // Each source is capped on its own, so no single stat (an extremely
  // long Endless run, say) can dwarf every other kind of progress.
  final xpFromStreak = inputs.daily.bestStreak.clamp(0, 60) * 5;
  final xpFromEndless = inputs.endless.bestRoundsCleared.clamp(0, 150) * 3;
  final unlockedAchievements = kMazeAchievements.where((a) => a.isUnlocked(inputs)).length;
  final xpFromAchievements = unlockedAchievements * 50;

  return xpFromStars +
      xpFromFacts +
      xpFromNoHints +
      xpFromStreak +
      xpFromEndless +
      xpFromAchievements;
}

/// XP needed to be AT [level] (level 1 starts at 0). Quadratic, so early
/// levels come quickly and later ones take progressively longer.
int explorerLevelThreshold(int level) => level <= 1 ? 0 : 50 * (level - 1) * (level - 1);

int explorerLevelForXp(int xp) {
  var level = 1;
  while (xp >= explorerLevelThreshold(level + 1)) {
    level++;
  }
  return level;
}

/// Everything a level badge/bar needs to render: the level itself, and
/// how far through it the current XP sits.
class ExplorerLevelInfo {
  const ExplorerLevelInfo({
    required this.level,
    required this.xp,
    required this.levelStartXp,
    required this.nextLevelXp,
  });

  final int level;
  final int xp;
  final int levelStartXp;
  final int nextLevelXp;

  /// 0.0 (just reached this level) to 1.0 (about to level up).
  double get progressToNext {
    final span = nextLevelXp - levelStartXp;
    if (span <= 0) return 1.0;
    return ((xp - levelStartXp) / span).clamp(0.0, 1.0);
  }
}

ExplorerLevelInfo explorerLevelInfoForXp(int xp) {
  final level = explorerLevelForXp(xp);
  return ExplorerLevelInfo(
    level: level,
    xp: xp,
    levelStartXp: explorerLevelThreshold(level),
    nextLevelXp: explorerLevelThreshold(level + 1),
  );
}
