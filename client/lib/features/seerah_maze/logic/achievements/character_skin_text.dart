import '../../../../l10n/app_localizations.dart';
import '../../models/maze_character_skin.dart';

/// D3 — a skin's name, resolved live against the active locale. Kept out
/// of models/maze_character_skin.dart itself for the same reason
/// mazeLevelTextFor is kept out of MazeLevel.
String mazeCharacterSkinNameFor(AppLocalizations t, MazeCharacterSkinId id) {
  switch (id) {
    case MazeCharacterSkinId.traveler:
      return t.mazeSkinTravelerName;
    case MazeCharacterSkinId.golden:
      return t.mazeSkinGoldenName;
    case MazeCharacterSkinId.ink:
      return t.mazeSkinInkName;
    case MazeCharacterSkinId.oasis:
      return t.mazeSkinOasisName;
  }
}
