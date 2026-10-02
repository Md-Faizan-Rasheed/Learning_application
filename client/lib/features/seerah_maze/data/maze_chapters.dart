import '../../../l10n/app_localizations.dart';

/// One thematic era of the 10-level journey, grouping consecutive levels
/// under a shared title drawn as a band behind the journey map (B1).
/// Purely a display grouping — it carries no gameplay data and doesn't
/// affect unlocking, generation, or any mechanic.
///
/// REVIEW WITH A SCHOLAR/TEACHER BEFORE RELEASE: the chapter boundaries
/// below reflect one reasonable grouping of the Seerah milestones already
/// chosen for levels 1-10 (see data/maze_levels.dart's level-by-level
/// character/destination pairs) into eras — early life, the call to
/// prophethood, the Hijrah, Madinah and the return — but that framing is a
/// first draft like the rest of this feature's narrative text and needs a
/// real review pass before shipping.
class MazeChapter {
  const MazeChapter({required this.id, required this.firstLevelId, required this.lastLevelId});

  final int id;
  final int firstLevelId;
  final int lastLevelId;

  bool contains(int levelId) => levelId >= firstLevelId && levelId <= lastLevelId;
}

const List<MazeChapter> kMazeChapters = [
  MazeChapter(id: 1, firstLevelId: 1, lastLevelId: 4),
  MazeChapter(id: 2, firstLevelId: 5, lastLevelId: 6),
  MazeChapter(id: 3, firstLevelId: 7, lastLevelId: 8),
  MazeChapter(id: 4, firstLevelId: 9, lastLevelId: 10),
];

/// The chapter a given level belongs to. Every level 1-10 is covered by
/// exactly one of [kMazeChapters], so this never falls through to the
/// first chapter as a silent default for an out-of-range id — it asserts
/// instead, since that would mean kMazeChapters is out of sync with
/// kMazeLevels.
MazeChapter mazeChapterFor(int levelId) {
  for (final chapter in kMazeChapters) {
    if (chapter.contains(levelId)) return chapter;
  }
  throw ArgumentError('no chapter covers level $levelId — kMazeChapters is out of date');
}

String mazeChapterTitleFor(AppLocalizations t, int chapterId) => switch (chapterId) {
      1 => t.mazeChapter1Title,
      2 => t.mazeChapter2Title,
      3 => t.mazeChapter3Title,
      _ => t.mazeChapter4Title,
    };
