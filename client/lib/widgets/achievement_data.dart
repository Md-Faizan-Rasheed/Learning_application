import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../utils/hijri_months.dart';
import '../utils/names_of_allah.dart';
import '../utils/prophet_names.dart';
import '../utils/word_search_generator.dart';

class Achievement {
  const Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
}

/// Achievements are derived purely from existing profile stats (XP, streak,
/// matches played) — no separate "unlocked" state is persisted anywhere,
/// since every criterion here is monotonic (once true, always true).
/// Every unlocked achievement shares one flat gold treatment; the icon
/// alone tells them apart, rather than a distinct color per achievement.
List<Achievement> achievementsFor(AppLocalizations t, Profile profile) {
  final xp = profile.totalXp;
  final streak = profile.streakDays;
  final matches = profile.recentMatches.length;
  final approvedQuestions = profile.approvedQuestionCount;
  final wsProgress = profile.wordSearchProgress;
  bool wsComplete(WordSearchCategory c, int total) =>
      (wsProgress[c.name] ?? 0) >= total;

  return [
    Achievement(
      title: t.achFirstStepsTitle,
      description: t.achFirstStepsDesc,
      icon: Icons.flag_rounded,
      unlocked: xp > 0 || matches > 0,
    ),
    Achievement(
      title: t.achCenturyClubTitle,
      description: t.achCenturyClubDesc,
      icon: Icons.stars_rounded,
      unlocked: xp >= 100,
    ),
    Achievement(
      title: t.achXpMasterTitle,
      description: t.achXpMasterDesc,
      icon: Icons.workspace_premium_rounded,
      unlocked: xp >= 500,
    ),
    Achievement(
      title: t.achXpLegendTitle,
      description: t.achXpLegendDesc,
      icon: Icons.auto_awesome_rounded,
      unlocked: xp >= 2000,
    ),
    Achievement(
      title: t.achOnFireTitle,
      description: t.achOnFireDesc,
      icon: Icons.local_fire_department_rounded,
      unlocked: streak >= 3,
    ),
    Achievement(
      title: t.achUnstoppableTitle,
      description: t.achUnstoppableDesc,
      icon: Icons.whatshot_rounded,
      unlocked: streak >= 7,
    ),
    Achievement(
      title: t.achDedicatedScholarTitle,
      description: t.achDedicatedScholarDesc,
      icon: Icons.emoji_events_rounded,
      unlocked: streak >= 30,
    ),
    Achievement(
      title: t.achContributorTitle,
      description: t.achContributorDesc,
      icon: Icons.edit_note_rounded,
      unlocked: approvedQuestions >= 1,
    ),
    Achievement(
      title: t.achKnowledgeBuilderTitle,
      description: t.achKnowledgeBuilderDesc,
      icon: Icons.local_library_rounded,
      unlocked: approvedQuestions >= 10,
    ),
    Achievement(
      title: t.achProphetScholarTitle,
      description: t.achProphetScholarDesc,
      icon: Icons.groups_2_rounded,
      unlocked: wsComplete(WordSearchCategory.prophets, kProphetNames.length),
    ),
    Achievement(
      title: t.achDivineNamesTitle,
      description: t.achDivineNamesDesc,
      icon: Icons.brightness_7_rounded,
      unlocked: wsComplete(WordSearchCategory.namesOfAllah, kNamesOfAllah.length),
    ),
    Achievement(
      title: t.achCalendarKeeperTitle,
      description: t.achCalendarKeeperDesc,
      icon: Icons.calendar_month_rounded,
      unlocked: wsComplete(WordSearchCategory.hijriMonths, kHijriMonths.length),
    ),
  ];
}
