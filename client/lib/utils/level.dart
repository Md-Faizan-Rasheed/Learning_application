/// Derives a player level/title purely from total XP. No backend concept of
/// "level" exists — this is a client-side presentation layer over the raw
/// XP number the server already tracks.
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.title,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.xpIntoLevel,
  });

  final int level;
  final String title;
  final int currentLevelXp;
  final int? nextLevelXp; // null at the final tier
  final int xpIntoLevel;

  double get progress {
    if (nextLevelXp == null) return 1.0;
    final span = nextLevelXp! - currentLevelXp;
    if (span <= 0) return 1.0;
    return (xpIntoLevel / span).clamp(0.0, 1.0);
  }

  int? get xpToNext => nextLevelXp == null ? null : nextLevelXp! - (currentLevelXp + xpIntoLevel);
}

const _kLevelThresholds = <int>[0, 50, 150, 300, 600, 1000, 1600, 2500, 4000, 6000];
const _kLevelTitles = <String>[
  'Newcomer',
  'Learner',
  'Devoted Student',
  'Rising Scholar',
  'Seerah Scholar',
  'Arabic Adept',
  'Knowledge Seeker',
  'Wise One',
  'Master Scholar',
  'Legend',
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
    title: _kLevelTitles[levelIndex],
    currentLevelXp: currentLevelXp,
    nextLevelXp: nextLevelXp,
    xpIntoLevel: totalXp - currentLevelXp,
  );
}
