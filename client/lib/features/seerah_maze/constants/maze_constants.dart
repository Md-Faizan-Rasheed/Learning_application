/// Tunable gameplay/animation constants for Seerah Maze, kept in one place
/// per the feature's "no hardcoded magic numbers" requirement. Grows across
/// later build steps (painters/UI add their own sizing/duration constants
/// here rather than inlining literals).
class MazeConstants {
  const MazeConstants._();

  // ---- Levels ----
  static const int totalLevels = 10;

  // ---- Collectibles & hints ----
  static const int collectibleStarCount = 3;
  static const int maxHintsPerLevel = 3;
  static const int hintPathLength = 4;
  static const Duration hintHighlightDuration = Duration(seconds: 3);

  // ---- Controls ----
  /// A drag target more than this many open-path steps from the player is
  /// ignored — prevents "drag straight to the destination" auto-solving.
  static const int maxDragFollowDistance = 3;
  static const Duration dragStepThrottle = Duration(milliseconds: 70);

  // ---- Movement animation ----
  static const Duration moveTweenDuration = Duration(milliseconds: 90);
  static const int trailLength = 6;

  // ---- Board layout ----
  /// Below this logical-pixel cell size, the board switches from
  /// shrinking cells to a pinch-zoom + follow-camera viewer instead, so a
  /// touch target never gets smaller than this.
  static const double minCellSize = 36;
  static const double maxBoardSize = 720;

  /// Width of the HUD when it renders as a side panel instead of a top
  /// bar — see ui/responsive/maze_breakpoints.dart and MazeHud's
  /// Axis.vertical layout.
  static const double hudSidePanelWidth = 104;

  /// Caps how wide a bottom sheet/dialog's content column grows on a
  /// tablet/desktop-size screen — unconstrained, a full-width sheet on a
  /// 1920px window reads as a stretched, badly-proportioned strip rather
  /// than a card. See ui/responsive/maze_breakpoints.dart's
  /// MazeResponsiveSheet.
  static const double maxSheetContentWidth = 480;

  /// Same idea for a full Scaffold body (e.g. level select) rather than a
  /// sheet — centers a readable column instead of stretching list items
  /// edge-to-edge on a wide window.
  static const double maxScreenContentWidth = 760;
  static const double boardCornerRadius = 24;
  static const double wallStrokeWidth = 5;
  static const double wallGlowBlur = 6;

  // ---- Board-entry / idle animations ----
  static const Duration boardBuildDuration = Duration(milliseconds: 600);
  static const Duration characterDropDuration = Duration(milliseconds: 450);
  static const Duration idleBreatheDuration = Duration(milliseconds: 1800);
  static const Duration bumpShakeDuration = Duration(milliseconds: 260);
  static const Duration destinationPulseDuration = Duration(milliseconds: 1600);
  static const Duration starSparkleDuration = Duration(milliseconds: 1400);

  // ---- Mechanics: fog / cave lantern (A1, A2) ----
  /// How long the fog veil takes to fade in when a level opens, so the
  /// board darkens smoothly instead of popping to black on frame one.
  static const Duration fogRevealDuration = Duration(milliseconds: 700);

  /// Light orbs are placed this many steps apart along a cave level's
  /// solution path — see CaveLantern.placeOrbs.
  static const int caveOrbSpacing = 5;

  /// How far the destination's own glow reaches through the cave veil, in
  /// cells — the faint "it's over there somewhere" hint A2 calls for,
  /// deliberately too soft to reveal the walls on the way to it.
  static const double caveDestinationGlowRadius = 1.6;

  /// Fraction of the veil the destination glow lifts (never all of it, so
  /// the destination stays a hint rather than a clear view).
  static const double caveDestinationGlowStrength = 0.45;

  // ---- Mechanics: doors and keys (A3) ----
  /// How long a door's opening swing plays for after its key is picked up.
  static const Duration doorOpenDuration = Duration(milliseconds: 420);

  // ---- Mechanics: one-way tiles and sand (A4) ----
  /// Dust puffed up where a sand slide skids to a stop.
  static const int slideDustParticleCount = 8;

  // ---- Story intro scene (B3) ----
  /// Per-character reveal delay for the typewriter story text.
  static const Duration introTypewriterCharDelay = Duration(milliseconds: 22);

  /// However long the story text is, the reveal never takes longer than
  /// this — a very long story still finishes in a reasonable time.
  static const Duration introTypewriterMaxDuration = Duration(milliseconds: 2400);
  static const Duration introTypewriterMinDuration = Duration(milliseconds: 300);

  static const double introSceneHeight = 96;

  // ---- Mechanics: teleport tents (A5) ----
  /// The fade/scale played when a tent jump lands.
  static const Duration teleportJumpDuration = Duration(milliseconds: 360);

  /// Sparkle puffed out at the arrival tent.
  static const int teleportArriveParticleCount = 12;

  // ---- Particles ----
  static const int starBurstParticleCount = 10;
  static const int winBurstMaxParticles = 80;
  static const Duration starBurstDuration = Duration(milliseconds: 650);

  // ---- Keyboard ----
  static const Duration keyRepeatInterval = Duration(milliseconds: 140);
}
