/// Per-level opt-in configuration for Seerah Maze's Phase 2 mechanics.
///
/// Every mechanic is off by default, so a level that doesn't mention one
/// behaves exactly as it did in Phase 1 — this is what lets the whole
/// mechanic set land incrementally without re-tuning the original ten
/// levels. Each mechanic's parameters live in their own small value class
/// here (rather than as loose fields on [MazeLevel]) so adding the next
/// mechanic never changes the shape of the others.
///
/// This stays a plain compile-time-const data holder with no UI or
/// `dart:ui` dependency, so `kMazeLevels` remains a `const` list and the
/// pure-Dart logic layer can read it directly in tests.
class MazeMechanics {
  const MazeMechanics({
    this.fog,
    this.cave,
    this.doors,
    this.oneWay,
    this.sand,
    this.teleports,
    this.caravans,
    this.sandstorm,
    this.shiftingWalls,
  });

  /// No mechanics at all — the Phase 1 behavior, and the default for every
  /// level that doesn't opt in.
  static const none = MazeMechanics();

  /// A1: fog of discovery. Null means the whole board stays visible.
  final FogConfig? fog;

  /// A2: dark cave / lantern mode. Null means normal lighting.
  final CaveConfig? cave;

  /// A3: locked doors and their keys. Null means no doors.
  final DoorConfig? doors;

  /// A4: one-way arrow tiles. Null means every passage works both ways.
  final OneWayConfig? oneWay;

  /// A4: slippery sand tiles. Null means no sand.
  final SandConfig? sand;

  /// A5: linked teleport tents. Null means no tents.
  final TeleportConfig? teleports;

  /// A6: patrolling caravans. Null means none.
  final CaravanConfig? caravans;

  /// A6: the sandstorm. Null means none.
  final SandstormConfig? sandstorm;

  /// A7: passages that periodically close and reopen. Null means none.
  final ShiftingWallsConfig? shiftingWalls;

  bool get hasFog => fog != null;
  bool get hasCave => cave != null;
  bool get hasDoors => doors != null;
  bool get hasOneWay => oneWay != null;
  bool get hasSand => sand != null;
  bool get hasTeleports => teleports != null;
  bool get hasCaravans => caravans != null;
  bool get hasSandstorm => sandstorm != null;
  bool get hasShiftingWalls => shiftingWalls != null;

  /// A8 — which mechanics on this level need a first-time introduction.
  /// Fog is deliberately excluded: it's a player-opted settings toggle,
  /// never something a level springs on someone unannounced.
  Set<MazeMechanicTooltip> get introducedTooltips => {
        if (hasCave) MazeMechanicTooltip.cave,
        if (hasDoors) MazeMechanicTooltip.doors,
        if (hasOneWay) MazeMechanicTooltip.oneWay,
        if (hasSand) MazeMechanicTooltip.sand,
        if (hasTeleports) MazeMechanicTooltip.teleport,
        if (hasCaravans) MazeMechanicTooltip.caravan,
        if (hasSandstorm) MazeMechanicTooltip.sandstorm,
        if (hasShiftingWalls) MazeMechanicTooltip.shiftingWalls,
      };
}

/// A8 — one mechanic worth a one-time "here's how this works" tooltip the
/// first time a level introduces it. Order here is the order a queue of
/// several (e.g. level 8's sand + sandstorm) displays in.
enum MazeMechanicTooltip {
  caravan,
  cave,
  doors,
  sand,
  sandstorm,
  teleport,
  shiftingWalls,
  oneWay,
}

/// A7 — shifting wall parameters.
class ShiftingWallsConfig {
  const ShiftingWallsConfig({
    this.toggleCount = 1,
    this.interval = const Duration(seconds: 15),
    this.warningLead = const Duration(milliseconds: 1500),
  });

  /// How many passages may shift. Kept small deliberately: every
  /// combination of states is validated, and more importantly a maze where
  /// lots of walls move is disorienting rather than interesting.
  final int toggleCount;

  /// How long a passage holds one state before flipping.
  final Duration interval;

  /// How long before a flip the glow cue shows.
  final Duration warningLead;
}

/// A6 — patrolling caravan parameters.
class CaravanConfig {
  const CaravanConfig({
    this.caravanCount = 1,
    this.cycle = const Duration(seconds: 8),
    this.pushBackCells = 2,
  });

  /// How many caravans to place, if the maze has straight corridors to
  /// spare.
  final int caravanCount;

  /// How long one there-and-back patrol takes.
  final Duration cycle;

  /// How far back the player is nudged on contact. Never a fail state —
  /// the cost is only the time it takes to walk it again.
  final int pushBackCells;
}

/// A6 — sandstorm parameters. The cycle is `period` long, ending with
/// `blockedDuration` of closure, preceded by `warningLead` of warning.
class SandstormConfig {
  const SandstormConfig({
    this.period = const Duration(seconds: 12),
    this.blockedDuration = const Duration(seconds: 4),
    this.warningLead = const Duration(seconds: 1),
    this.maxTargets = 3,
  });

  final Duration period;
  final Duration blockedDuration;
  final Duration warningLead;

  /// How many different cells the storm rotates between.
  final int maxTargets;
}

/// A5 — linked teleport tents.
class TeleportConfig {
  const TeleportConfig({
    this.pairCount = 1,
    this.minShortcutFraction = 0.6,
    this.cooldown = const Duration(seconds: 1),
  });

  /// How many linked pairs to place (the spec's 1-2 per level).
  final int pairCount;

  /// A pair is rejected if it cuts the shortest solution below this
  /// fraction of its original length — that's what stops a tent from
  /// turning the maze into a two-step skip. 1.0 would forbid any
  /// shortening at all; 0.6 keeps at least 60% of the original journey.
  final double minShortcutFraction;

  /// How long after a jump the tents refuse to fire again, so a player
  /// standing on one can't spam it.
  final Duration cooldown;
}

/// A4 — one-way arrow tiles. Stepping onto one commits you: the only way
/// off it is the way the arrow points.
class OneWayConfig {
  const OneWayConfig({this.tileCount = 2});

  /// How many arrow tiles to try to place. Candidates that would let the
  /// player strand themselves are rejected, so the final count can be
  /// lower — see MazeMovementRules.placeOneWays.
  final int tileCount;
}

/// A4 — slippery sand. Stepping onto sand slides you onward in the same
/// direction until a wall stops you or you reach solid ground.
class SandConfig {
  const SandConfig({this.patchCount = 2, this.patchLength = 3});

  /// How many separate runs of sand to place.
  final int patchCount;

  /// How many cells long each run is, at most.
  final int patchLength;
}

/// A3 — locked door parameters.
class DoorConfig {
  const DoorConfig({this.doorCount = 1});

  /// How many doors to place along the level's solution path. Capped at
  /// the number of distinct key kinds, and silently reduced if the maze
  /// can't host that many solvably — see DoorsAndKeys.place.
  final int doorCount;
}

/// A1 — fog of discovery parameters. The player sees cells within
/// [visibilityRadius] of their position; cells they've previously stood
/// within stay faintly "remembered"; everything else is hidden.
class FogConfig {
  const FogConfig({
    this.visibilityRadius = 2.5,
    this.rememberedOpacity = 0.55,
    this.hiddenOpacity = 0.96,
  });

  /// In cells, measured as straight-line (euclidean) distance from the
  /// player — fractional so a radius can sit between "just the 4 orthogonal
  /// neighbours" (1.0) and "the full 3x3 block including diagonals" (1.5).
  final double visibilityRadius;

  /// How strongly a previously-seen-but-not-currently-lit cell is veiled
  /// (0 = fully clear, 1 = fully hidden).
  final double rememberedOpacity;

  /// How strongly a never-seen cell is veiled. Deliberately just under 1.0
  /// so the board's silhouette still reads as a maze rather than a black
  /// rectangle.
  final double hiddenOpacity;
}

/// A2 — dark cave / lantern mode parameters (Hira and Thawr levels).
class CaveConfig {
  const CaveConfig({
    this.lanternRadius = 1.8,
    this.boostedLanternRadius = 3.4,
    this.boostDuration = const Duration(seconds: 10),
    this.flickerAmplitude = 0.12,
  });

  /// Base lit radius around the player, in cells.
  final double lanternRadius;

  /// Lit radius while a light-orb pickup is active.
  final double boostedLanternRadius;

  /// How long a light-orb pickup widens the lantern for.
  final Duration boostDuration;

  /// Fraction of the radius the gentle flicker varies by (0 = steady).
  final double flickerAmplitude;
}
