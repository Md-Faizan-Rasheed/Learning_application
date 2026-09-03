import '../l10n/app_localizations.dart';

/// Derives a player level/title purely from total XP. No backend concept of
/// "level" exists — this is a client-side presentation layer over the raw
/// XP number the server already tracks.
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.titleIndex,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.xpIntoLevel,
  });

  final int level;
  final int titleIndex;
  final int currentLevelXp;
  final int? nextLevelXp; // null at the final tier
  final int xpIntoLevel;

  String title(AppLocalizations t) => _kLevelTitleGetters[titleIndex](t);

  double get progress {
    if (nextLevelXp == null) return 1.0;
    final span = nextLevelXp! - currentLevelXp;
    if (span <= 0) return 1.0;
    return (xpIntoLevel / span).clamp(0.0, 1.0);
  }

  int? get xpToNext => nextLevelXp == null ? null : nextLevelXp! - (currentLevelXp + xpIntoLevel);
}

const _kLevelThresholds = <int>[0, 50, 150, 300, 600, 1000, 1600, 2500, 4000, 6000];
final _kLevelTitleGetters = <String Function(AppLocalizations)>[
  (t) => t.levelNewcomer,
  (t) => t.levelLearner,
  (t) => t.levelDevotedStudent,
  (t) => t.levelRisingScholar,
  (t) => t.levelSeerahScholar,
  (t) => t.levelArabicAdept,
  (t) => t.levelKnowledgeSeeker,
  (t) => t.levelWiseOne,
  (t) => t.levelMasterScholar,
  (t) => t.levelLegend,
];

LevelInfo levelForXp(int totalXp) {
  var levelIndex = 0;
  for (var i = 0; i < _kLevelThresholds.length; i++) {
    if (totalXp >= _kLevelThresholds[i]) {
      levelIndex = i;
    } else {
      break;
    }
  }

  final currentLevelXp = _kLevelThresholds[levelIndex];
  final isMax = levelIndex == _kLevelThresholds.length - 1;
  final nextLevelXp = isMax ? null : _kLevelThresholds[levelIndex + 1];

  return LevelInfo(
    level: levelIndex + 1,
    titleIndex: levelIndex,
    currentLevelXp: currentLevelXp,
    nextLevelXp: nextLevelXp,
    xpIntoLevel: totalXp - currentLevelXp,
  );
}
