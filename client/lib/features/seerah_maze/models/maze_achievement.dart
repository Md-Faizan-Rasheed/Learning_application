import 'package:flutter/material.dart';

import 'daily_maze_progress.dart';
import 'endless_best_run.dart';
import 'maze_progress.dart';

/// D1 — every achievement this feature tracks. Deliberately computed
/// entirely from data other parts of the feature already persist (stars,
/// facts, streaks, endless rounds, ghost records) — no new tracking
/// fields anywhere, just a read-only view over what's already saved.
enum MazeAchievementId {
  firstSteps,
  halfwayThere,
  journeysEnd,
  starCollector,
  perfectCampaign,
  seerahScholar,
  noHintsMaster,
  racingSpirit,
  gettingStarted,
  weekOfDevotion,
  habitFormed,
  enduranceRunner,
  centuryClub,
}

/// Everything an achievement's progress function might need to read.
/// [ghostLevelsRecorded] is the count of campaign levels with at least one
/// saved ghost run — not tracked anywhere itself, just computed once (by
/// whoever loads this bundle) from GhostRunRepository across all levels.
class MazeAchievementInputs {
  const MazeAchievementInputs({
    required this.progress,
    required this.daily,
    required this.endless,
    required this.ghostLevelsRecorded,
    required this.totalLevels,
  });

  final MazeProgress progress;
  final DailyMazeProgress daily;
  final EndlessBestRun endless;
  final int ghostLevelsRecorded;

  /// The campaign's level count (kMazeLevels.length) — passed in rather
  /// than imported directly, so this model stays free of a dependency on
  /// the concrete level list.
  final int totalLevels;
}

class MazeAchievementDef {
  const MazeAchievementDef({required this.id, required this.icon, required this.progressOf});

  final MazeAchievementId id;
  final IconData icon;

  /// 0.0 (not started) to 1.0 (unlocked). Always clamped by the function
  /// itself, so callers never need to re-clamp.
  final double Function(MazeAchievementInputs inputs) progressOf;

  bool isUnlocked(MazeAchievementInputs inputs) => progressOf(inputs) >= 1.0;
}

double _ratio(num value, num goal) => goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0).toDouble();

/// Ordered for display: campaign milestones first, then the per-mode
/// challenges, then the two cross-mode habit/endurance tracks.
final List<MazeAchievementDef> kMazeAchievements = [
  MazeAchievementDef(
    id: MazeAchievementId.firstSteps,
    icon: Icons.flag_rounded,
    progressOf: (i) => i.progress.starsByLevel.containsKey(1) ? 1.0 : 0.0,
  ),
  MazeAchievementDef(
    id: MazeAchievementId.halfwayThere,
    icon: Icons.hiking_rounded,
    progressOf: (i) => _ratio(i.progress.starsByLevel.length, (i.totalLevels / 2).ceil()),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.journeysEnd,
    icon: Icons.emoji_events_rounded,
    progressOf: (i) => _ratio(i.progress.starsByLevel.length, i.totalLevels),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.starCollector,
    icon: Icons.star_rounded,
    progressOf: (i) {
      final total = i.progress.starsByLevel.values.fold(0, (a, b) => a + b);
      return _ratio(total, (i.totalLevels * 3 * 0.5).round());
    },
  ),
  MazeAchievementDef(
    id: MazeAchievementId.perfectCampaign,
    icon: Icons.workspace_premium_rounded,
    progressOf: (i) {
      final total = i.progress.starsByLevel.values.fold(0, (a, b) => a + b);
      return _ratio(total, i.totalLevels * 3);
    },
  ),
  MazeAchievementDef(
    id: MazeAchievementId.seerahScholar,
    icon: Icons.menu_book_rounded,
    progressOf: (i) => _ratio(i.progress.collectedFactLevelIds.length, i.totalLevels),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.noHintsMaster,
    icon: Icons.visibility_off_rounded,
    progressOf: (i) => _ratio(i.progress.noHintsClearedLevelIds.length, i.totalLevels),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.racingSpirit,
    icon: Icons.bolt_rounded,
    progressOf: (i) => _ratio(i.ghostLevelsRecorded, (i.totalLevels / 2).ceil()),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.gettingStarted,
    icon: Icons.whatshot_rounded,
    progressOf: (i) => _ratio(i.daily.bestStreak, 3),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.weekOfDevotion,
    icon: Icons.local_fire_department_rounded,
    progressOf: (i) => _ratio(i.daily.bestStreak, 7),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.habitFormed,
    icon: Icons.auto_awesome_rounded,
    progressOf: (i) => _ratio(i.daily.bestStreak, 30),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.enduranceRunner,
    icon: Icons.directions_run_rounded,
    progressOf: (i) => _ratio(i.endless.bestRoundsCleared, 10),
  ),
  MazeAchievementDef(
    id: MazeAchievementId.centuryClub,
    icon: Icons.military_tech_rounded,
    progressOf: (i) => _ratio(i.endless.bestRoundsCleared, 100),
  ),
];
