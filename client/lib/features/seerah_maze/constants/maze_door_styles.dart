import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../models/maze_door.dart';

/// How each key kind looks. Every kind differs by **shape as well as
/// color** — the badge icon and the little notch pattern drawn on the door
/// bar both change — so a player who can't tell the three colors apart can
/// still match a key to its door, per the accessibility rule that color is
/// never the only signal.
class MazeDoorStyle {
  const MazeDoorStyle({
    required this.color,
    required this.icon,
    required this.notches,
  });

  final Color color;

  /// Shown on the key pickup and in the HUD inventory.
  final IconData icon;

  /// How many notches are drawn across the door bar — the shape cue that
  /// matches this kind's key without relying on hue.
  final int notches;
}

const Map<MazeKeyKind, MazeDoorStyle> kMazeDoorStyles = {
  MazeKeyKind.brass: MazeDoorStyle(
    color: AppPalette.mutedGold,
    icon: Icons.vpn_key_rounded,
    notches: 1,
  ),
  // incorrectRed is the palette's only warm red; used here as a door tone,
  // not as an error signal, which is why it's paired with its own distinct
  // icon and notch count rather than standing on the color alone.
  MazeKeyKind.copper: MazeDoorStyle(
    color: AppPalette.incorrectRed,
    icon: Icons.key_rounded,
    notches: 2,
  ),
  MazeKeyKind.silver: MazeDoorStyle(
    color: AppPalette.deepTeal,
    icon: Icons.vpn_key_outlined,
    notches: 3,
  ),
};

MazeDoorStyle mazeDoorStyleFor(MazeKeyKind kind) =>
    kMazeDoorStyles[kind] ?? kMazeDoorStyles[MazeKeyKind.brass]!;
