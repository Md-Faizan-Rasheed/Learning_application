import '../../../l10n/app_localizations.dart';

/// B4 — the collectible Seerah fact tied to each level's own milestone
/// (one scroll per level; see logic/collectibles/fact_scroll_placement.dart
/// for where it sits in the maze). Purely informational — "no questions,
/// no scoring beyond collection count" — so there's no right/wrong
/// answer to track, just whether it's been found.
///
/// REVIEW WITH A SCHOLAR/TEACHER BEFORE RELEASE: every fact below is a
/// first draft, written to stay within mainstream, well-documented Seerah
/// accounts and to avoid anything disputed, but it still needs a real
/// review pass before shipping — the same standard every other piece of
/// narrative text in this feature (data/maze_levels.dart's story/winLine
/// strings) already carries.
String mazeFactTextFor(AppLocalizations t, int levelId) => switch (levelId) {
      1 => t.mazeFactLevel1,
      2 => t.mazeFactLevel2,
      3 => t.mazeFactLevel3,
      4 => t.mazeFactLevel4,
      5 => t.mazeFactLevel5,
      6 => t.mazeFactLevel6,
      7 => t.mazeFactLevel7,
      8 => t.mazeFactLevel8,
      9 => t.mazeFactLevel9,
      _ => t.mazeFactLevel10,
    };
