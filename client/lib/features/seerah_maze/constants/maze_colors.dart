import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Every color Seerah Maze uses, derived from this app's real
/// `AppPalette` tokens (parchment/deep-teal/muted-gold/ink) rather than a
/// new hue set — kept in this one file so nothing in painters/ or ui/ ever
/// hardcodes a literal `Color(0x...)` of its own. This app's palette has
/// no navy or violet note; the "dark-to-teal" background gradient below is
/// built from `AppPalette.ink` -> `AppPalette.deepTeal` to stay within the
/// existing token set.
class MazeColors {
  const MazeColors._();

  static const background = [AppPalette.ink, AppPalette.deepTeal];
  static const boardPanel = AppPalette.cardStock;
  static Color get boardPanelShadow => AppPalette.shadowInk;
  static const boardBorder = AppPalette.borderTaupe;

  static const wall = AppPalette.mutedGold;
  static Color get wallGlow => AppPalette.mutedGold.withValues(alpha: 0.45);
  static const wallOutline = AppPalette.ink;

  static const characterFill = AppPalette.deepTeal;
  static Color get characterShadow => AppPalette.ink.withValues(alpha: 0.25);
  static const trail = AppPalette.mutedGold;

  static const lightMarkerCore = AppPalette.cardStock;
  static const lightMarkerGlow = AppPalette.mutedGold;

  static const destinationRing = AppPalette.mutedGold;
  static const destinationIcon = AppPalette.deepTeal;

  static const star = AppPalette.mutedGold;
  static const starSparkle = AppPalette.cardStock;

  static Color get fogOverlay => AppPalette.ink.withValues(alpha: 0.35);

  /// Base color of the Phase 2 fog/lantern veil (painters/fog_painter.dart
  /// supplies its own alpha per visibility band, so this is the opaque
  /// ink tone rather than a pre-faded one).
  static const fogVeil = AppPalette.ink;

  // A4 — slippery sand and one-way arrow tiles. Both stay inside the
  // existing parchment/gold token set rather than introducing new hues.
  static Color get sandFill => AppPalette.parchmentDeep.withValues(alpha: 0.22);
  static Color get sandStipple => AppPalette.mutedGold.withValues(alpha: 0.5);
  static Color get oneWayArrow => AppPalette.mutedGold.withValues(alpha: 0.85);

  /// A5 — glow color per teleport pair. Two tones only, because a level
  /// never has more than two pairs; the painter also draws one pip per
  /// pair, so the pairing never rests on color alone.
  static Color teleportGlowFor(int pairIndex) =>
      pairIndex.isEven ? AppPalette.deepTeal : AppPalette.mutedGold;

  // A6 — caravan and sandstorm. The caravan is an ink silhouette (no face,
  // per this feature's rule); the storm borrows the parchment/gold tones so
  // it reads as blowing sand rather than as a new colour in the palette.
  static const caravanBody = AppPalette.ink;
  static Color get stormCore => AppPalette.parchmentDeep.withValues(alpha: 0.9);
  static Color get stormGrain => AppPalette.mutedGold.withValues(alpha: 0.8);
  static Color get stormWarning => AppPalette.incorrectRed;

  /// A7 — the glow marking a passage that is about to shift.
  static Color get shiftingWallCue => AppPalette.mutedGold;

  /// B4 — the collectible fact scroll's parchment body and end caps.
  static const scrollParchment = AppPalette.cardStock;
  static const scrollCap = AppPalette.mutedGold;

  static Color get backgroundPattern => AppPalette.cardStock.withValues(alpha: 0.05);
}
