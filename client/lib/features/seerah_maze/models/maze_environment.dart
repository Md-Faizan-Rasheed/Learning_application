import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// B2 — the kind of ambient particle an environment drifts: dust motes
/// (desert/caravan), fireflies (oasis), or stars (night).
enum MazeAmbientParticleType { dust, fireflies, stars }

/// B2 — the silhouette shape a parallax layer draws. [ridge] is one
/// flexible renderer for both dunes (low jaggedness) and distant rocks
/// (high jaggedness), rather than two separate bespoke painters for what
/// is visually the same kind of shape at different roughness.
enum MazeParallaxShape { ridge, palms }

/// One parallax layer: a silhouette strip at a given depth, drawn behind
/// the maze board. [depth] also sets how strongly it shifts with the
/// player's own movement (0 = fixed backdrop, 1 = shifts almost as much
/// as the character) — the spec's "parallax responds subtly to character
/// movement", kept subtle by every depth value staying well under 1.
class MazeParallaxLayer {
  const MazeParallaxLayer({
    required this.shape,
    required this.color,
    required this.depth,
    this.jaggedness = 0.3,
  });

  final MazeParallaxShape shape;
  final Color color;

  /// 0..1, how much this layer shifts with character movement and camera
  /// pan — small values for a "distant" layer, larger for "near".
  final double depth;

  /// Only meaningful for [MazeParallaxShape.ridge]: 0 = smooth dune curves,
  /// 1 = jagged rock peaks.
  final double jaggedness;
}

/// B2 — one level's complete atmosphere: background gradient, 2-3 parallax
/// layers, a wall/glow tint, and an ambient particle type. Every color
/// here is derived from [AppPalette] tokens (via blending, not new hex
/// literals) — six different-*feeling* atmospheres without six different
/// hue families, the same discipline the rest of this feature's palette
/// follows.
class MazeEnvironmentTheme {
  const MazeEnvironmentTheme({
    required this.id,
    required this.backgroundGradient,
    required this.parallaxLayers,
    required this.wallTint,
    required this.glowTint,
    required this.particleType,
  });

  final MazeEnvironmentId id;
  final List<Color> backgroundGradient;
  final List<MazeParallaxLayer> parallaxLayers;

  /// Replaces MazeColors.wall for levels using this theme — a lerp of the
  /// base gold wall tone, not an unrelated color, so every level still
  /// reads as the same maze with a different time-of-day/place cast over
  /// it rather than a different game.
  final Color wallTint;
  final Color glowTint;

  final MazeAmbientParticleType particleType;
}

enum MazeEnvironmentId {
  makkahDawn,
  desertDay,
  caravanSunset,
  desertNightStars,
  rockyCave,
  madinahOasis,
}

/// The six named atmospheres from the spec, each blended from
/// [AppPalette]'s existing tokens only.
final Map<MazeEnvironmentId, MazeEnvironmentTheme> kMazeEnvironmentThemes = {
  MazeEnvironmentId.makkahDawn: MazeEnvironmentTheme(
    id: MazeEnvironmentId.makkahDawn,
    backgroundGradient: [
      AppPalette.ink,
      Color.lerp(AppPalette.deepTeal, AppPalette.mutedGold, 0.3)!,
    ],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.ink.withValues(alpha: 0.55),
        depth: 0.08,
        jaggedness: 0.15,
      ),
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: Color.lerp(AppPalette.deepTeal, AppPalette.ink, 0.3)!.withValues(alpha: 0.65),
        depth: 0.18,
        jaggedness: 0.1,
      ),
    ],
    wallTint: AppPalette.mutedGold,
    glowTint: AppPalette.mutedGold,
    particleType: MazeAmbientParticleType.dust,
  ),
  MazeEnvironmentId.desertDay: MazeEnvironmentTheme(
    id: MazeEnvironmentId.desertDay,
    backgroundGradient: [AppPalette.parchmentDeep, AppPalette.cardStock],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.borderTaupe.withValues(alpha: 0.6),
        depth: 0.08,
        jaggedness: 0.05,
      ),
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.mutedGold.withValues(alpha: 0.35),
        depth: 0.2,
        jaggedness: 0.1,
      ),
    ],
    wallTint: Color.lerp(AppPalette.mutedGold, AppPalette.ink, 0.1)!,
    glowTint: AppPalette.mutedGold,
    particleType: MazeAmbientParticleType.dust,
  ),
  MazeEnvironmentId.caravanSunset: MazeEnvironmentTheme(
    id: MazeEnvironmentId.caravanSunset,
    backgroundGradient: [
      AppPalette.deepTeal,
      Color.lerp(AppPalette.mutedGold, AppPalette.ink, 0.25)!,
    ],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.ink.withValues(alpha: 0.6),
        depth: 0.09,
        jaggedness: 0.08,
      ),
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.mutedGold.withValues(alpha: 0.4),
        depth: 0.22,
        jaggedness: 0.12,
      ),
    ],
    wallTint: Color.lerp(AppPalette.mutedGold, AppPalette.incorrectRed, 0.15)!,
    glowTint: AppPalette.mutedGold,
    particleType: MazeAmbientParticleType.dust,
  ),
  MazeEnvironmentId.desertNightStars: const MazeEnvironmentTheme(
    id: MazeEnvironmentId.desertNightStars,
    backgroundGradient: [AppPalette.ink, AppPalette.deepTeal],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.ink,
        depth: 0.08,
        jaggedness: 0.1,
      ),
    ],
    wallTint: AppPalette.deepTeal,
    glowTint: AppPalette.mutedGold,
    particleType: MazeAmbientParticleType.stars,
  ),
  MazeEnvironmentId.rockyCave: MazeEnvironmentTheme(
    id: MazeEnvironmentId.rockyCave,
    backgroundGradient: [
      Color.lerp(AppPalette.ink, Colors.black, 0.4)!,
      AppPalette.ink,
    ],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: Colors.black.withValues(alpha: 0.5),
        depth: 0.1,
        jaggedness: 0.85,
      ),
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.ink.withValues(alpha: 0.7),
        depth: 0.2,
        jaggedness: 0.95,
      ),
    ],
    wallTint: Color.lerp(AppPalette.mutedGold, AppPalette.ink, 0.35)!,
    glowTint: Color.lerp(AppPalette.mutedGold, AppPalette.deepTeal, 0.2)!,
    particleType: MazeAmbientParticleType.dust,
  ),
  MazeEnvironmentId.madinahOasis: MazeEnvironmentTheme(
    id: MazeEnvironmentId.madinahOasis,
    backgroundGradient: [
      Color.lerp(AppPalette.deepTeal, AppPalette.barkGreen, 0.35)!,
      AppPalette.parchmentDeep,
    ],
    parallaxLayers: [
      MazeParallaxLayer(
        shape: MazeParallaxShape.palms,
        color: Color.lerp(AppPalette.deepTeal, AppPalette.barkGreen, 0.5)!.withValues(alpha: 0.8),
        depth: 0.16,
      ),
      MazeParallaxLayer(
        shape: MazeParallaxShape.ridge,
        color: AppPalette.borderTaupe.withValues(alpha: 0.5),
        depth: 0.08,
        jaggedness: 0.05,
      ),
    ],
    wallTint: Color.lerp(AppPalette.mutedGold, AppPalette.barkGreen, 0.2)!,
    glowTint: AppPalette.mutedGold,
    particleType: MazeAmbientParticleType.fireflies,
  ),
};
