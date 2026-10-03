import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// D3 — cosmetic character/trail recolors, unlocked by Explorer Level
/// (see logic/achievements/explorer_level.dart). Every color here is
/// built only from AppPalette's existing tokens — no new hues — same
/// discipline constants/maze_colors.dart already follows for everything
/// else in this feature.
enum MazeCharacterSkinId { traveler, golden, ink, oasis }

class MazeCharacterSkinDef {
  const MazeCharacterSkinDef({
    required this.id,
    required this.unlockLevel,
    required this.fillColor,
    required this.trailColor,
  });

  final MazeCharacterSkinId id;

  /// The Explorer Level required to use this skin. 1 means always
  /// available.
  final int unlockLevel;
  final Color fillColor;
  final Color trailColor;
}

/// The default look — identical to MazeColors.characterFill/trail, so a
/// level 1 player sees exactly the same silhouette this feature always
/// had.
final List<MazeCharacterSkinDef> kMazeCharacterSkins = [
  const MazeCharacterSkinDef(
    id: MazeCharacterSkinId.traveler,
    unlockLevel: 1,
    fillColor: AppPalette.deepTeal,
    trailColor: AppPalette.mutedGold,
  ),
  const MazeCharacterSkinDef(
    id: MazeCharacterSkinId.golden,
    unlockLevel: 3,
    fillColor: AppPalette.mutedGold,
    trailColor: AppPalette.deepTeal,
  ),
  const MazeCharacterSkinDef(
    id: MazeCharacterSkinId.ink,
    unlockLevel: 5,
    fillColor: AppPalette.ink,
    trailColor: AppPalette.mutedGold,
  ),
  MazeCharacterSkinDef(
    id: MazeCharacterSkinId.oasis,
    unlockLevel: 7,
    fillColor: Color.lerp(AppPalette.deepTeal, AppPalette.barkGreen, 0.55)!,
    trailColor: AppPalette.barkGreen,
  ),
];

MazeCharacterSkinDef mazeCharacterSkinDefFor(MazeCharacterSkinId id) =>
    kMazeCharacterSkins.firstWhere((s) => s.id == id);
