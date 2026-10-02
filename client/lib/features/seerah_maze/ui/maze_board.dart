import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../logic/game_controller.dart';
import '../logic/maze_solver.dart';
import '../logic/mechanics/cave_lantern.dart';
import '../logic/mechanics/fog_of_discovery.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import '../models/maze_door.dart';
import '../models/maze_environment.dart';
import '../models/maze_mechanics.dart';
import '../painters/character_painter.dart';
import '../painters/door_painter.dart';
import '../painters/fog_painter.dart';
import '../painters/obstacle_painter.dart';
import '../painters/shifting_wall_painter.dart';
import '../painters/maze_geometry.dart';
import '../painters/maze_painter.dart';
import '../painters/particle_painter.dart';

/// The interactive maze board: renders the current level and owns every
/// input path (drag, keyboard, tap-to-step in zoomed mode) that drives the
/// given [controller]. Deliberately knows nothing about HUD/pause/win-card
/// chrome — a parent screen (added in a later build step) wraps this and
/// reacts to [onStarCollected]/[onWon]; this widget only renders the board
/// itself and keeps [controller] (already built in step 2, pure Dart)
/// in sync with what the player does.
///
/// Layering follows the project's performance requirement: the walls are
/// recorded once into a cached `ui.Picture` and replayed every frame
/// (near-zero cost) in their own RepaintBoundary, fully separate from the
/// per-frame-animated destination/stars/character/particles layers above
/// it — only those repaint on every tick.
class MazeBoardWidget extends StatefulWidget {
  const MazeBoardWidget({
    super.key,
    required this.controller,
    required this.solver,
    this.onMoved,
    this.onBumped,
    this.onStarCollected,
    this.onLightOrbCollected,
    this.onKeyCollected,
    this.onTeleported,
    this.onCaravanBump,
    this.onFactCollected,
    this.onWon,
    this.fogEnabled = false,
    this.hintCells = const [],
    this.environmentTheme,
  });

  final GameController controller;
  final MazeSolver solver;
  final VoidCallback? onMoved;
  final VoidCallback? onBumped;
  final ValueChanged<MazeCoord>? onStarCollected;

  /// A2 — fired when the player walks onto a cave level's light orb and
  /// the lantern widens.
  final VoidCallback? onLightOrbCollected;

  /// A3 — fired when the player picks up a door key.
  final VoidCallback? onKeyCollected;

  /// A5 — fired when a tent jump lands.
  final VoidCallback? onTeleported;

  /// A6 — fired when a caravan nudges the player back.
  final VoidCallback? onCaravanBump;

  /// B4 — fired once when the level's fact scroll is collected.
  final VoidCallback? onFactCollected;

  final VoidCallback? onWon;
  final bool fogEnabled;
  final List<MazeCoord> hintCells;

  /// B2 — tints this level's wall/glow color. Null (any level not yet
  /// migrated to a theme) keeps the plain MazeColors.wall/wallGlow look.
  final MazeEnvironmentTheme? environmentTheme;

  @override
  State<MazeBoardWidget> createState() => _MazeBoardWidgetState();
}

class _MazeBoardWidgetState extends State<MazeBoardWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _moveController;
  Animation<Offset>? _moveAnimation;
  late AnimationController _idleController;
  late AnimationController _bumpController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;
  late AnimationController _buildController;
  late AnimationController _dropController;
  final TransformationController _transformController = TransformationController();

  final List<Offset> _trail = [];
  final List<MazeParticle> _particles = [];
  final math.Random _particleRandom = math.Random();
  Duration? _lastParticleTick;

  bool _isAnimatingMove = false;
  DateTime? _lastDragStepAt;
  Offset? _initialPixelCenter;

  ui.Picture? _wallsPicture;
  double _wallsPictureCellSize = -1;
  bool _wallsPictureFinal = false;

  late MazeGeometry _geometry = const MazeGeometry(cellSize: 1);
  bool _useZoom = false;
  Size _lastViewportSize = Size.zero;

  /// A1 — null when this level/setting combination has no fog at all, in
  /// which case the fog layer isn't built and costs nothing.
  FogOfDiscovery? _fog;
  late AnimationController _fogRevealController;

  /// A2 — null outside cave levels. When present it drives the fog
  /// layer's radius instead of the static fog config.
  CaveLantern? _lantern;

  /// Drives the lantern flicker and counts the boost down; only started on
  /// cave levels so ordinary levels gain no extra per-frame work.
  late AnimationController _lanternController;
  Duration _lanternElapsed = Duration.zero;
  Duration? _lastLanternTick;

  /// A3 — the door currently playing its opening swing, and the clock
  /// driving it. Also the last-seen key set, so a pickup can be spotted by
  /// diffing rather than threading a return value through every one of the
  /// three input paths that can cause a move.
  late AnimationController _doorOpenController;
  MazeDoor? _openingDoor;
  Set<MazeKeyKind> _lastKnownKeys = const {};

  /// A5 — drives the fade/scale on a tent jump.
  late AnimationController _teleportController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fogRevealController =
        AnimationController(vsync: this, duration: MazeConstants.fogRevealDuration)
          ..addListener(() => setState(() {}));
    // Duration is nominal — this one repeats purely as a per-frame clock
    // for the lantern flicker/boost, like _pulseController does for the
    // destination glow.
    _lanternController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_onLanternTick);
    _doorOpenController = AnimationController(vsync: this, duration: MazeConstants.doorOpenDuration)
      ..addListener(() => setState(() {}));
    _teleportController =
        AnimationController(vsync: this, duration: MazeConstants.teleportJumpDuration)
          ..addListener(() => setState(() {}));
    _lastKnownKeys = widget.controller.heldKeys;
    _initFog();
    _initLantern();

    _moveController = AnimationController(vsync: this, duration: MazeConstants.moveTweenDuration);
    _idleController = AnimationController(vsync: this, duration: MazeConstants.idleBreatheDuration)
      ..repeat(reverse: true);
    _bumpController = AnimationController(vsync: this, duration: MazeConstants.bumpShakeDuration)
      ..addListener(() => setState(() {}));
    _pulseController =
        AnimationController(vsync: this, duration: MazeConstants.destinationPulseDuration)
          ..repeat();
    _pulseController.addListener(_onPulseTick);
    _sparkleController =
        AnimationController(vsync: this, duration: MazeConstants.starSparkleDuration)..repeat();
    _buildController = AnimationController(vsync: this, duration: MazeConstants.boardBuildDuration)
      ..addListener(() => setState(() {}));
    _dropController =
        AnimationController(vsync: this, duration: MazeConstants.characterDropDuration);

    _buildController.forward();
    _dropController.forward();
  }

  /// Fog comes from one of three places: a cave level (A2, which is fog
  /// with a near-black veil and a lantern-driven radius), a level opting
  /// into ordinary fog (A1), or the player's own "fog mode" setting, which
  /// is how Phase 1 exposed it and stays supported with the default radius.
  void _initFog() {
    final mechanics = widget.controller.level.mechanics;
    final cave = mechanics.cave;
    final config = cave != null
        ? FogConfig(
            visibilityRadius: cave.lanternRadius,
            // A cave keeps almost nothing of what you've already walked
            // past, and hides the unseen entirely — "near-black" per A2,
            // versus ordinary fog's gentler dimming.
            rememberedOpacity: 0.82,
            hiddenOpacity: 0.99,
          )
        : mechanics.fog ?? (widget.fogEnabled ? const FogConfig() : null);
    if (config == null) {
      _fog = null;
      _fogRevealController.value = 0;
      return;
    }
    final fog = FogOfDiscovery(config: config);
    fog.reveal(
      playerPosition: widget.controller.playerPosition,
      mazeSize: widget.controller.maze.size,
    );
    _fog = fog;
    _fogRevealController.forward(from: 0);
  }

  /// A2 — cave levels light orbs along their own solution path, so the
  /// placement needs the solver once at level start (never per frame).
  void _initLantern() {
    final caveConfig = widget.controller.level.mechanics.cave;
    if (caveConfig == null) {
      _lantern = null;
      return;
    }
    final maze = widget.controller.maze;
    final path = widget.solver.shortestPath(maze, maze.start, maze.destination) ?? const [];
    _lantern = CaveLantern(
      config: caveConfig,
      orbCells: CaveLantern.placeOrbs(
        solutionPath: path,
        spacing: MazeConstants.caveOrbSpacing,
        exclude: maze.starCoords.toSet(),
      ),
    );
    _lanternElapsed = Duration.zero;
    _lastLanternTick = null;
    _lanternController.repeat();
  }

  void _onLanternTick() {
    final lantern = _lantern;
    if (lantern == null) return;
    final now = _lanternController.lastElapsedDuration ?? Duration.zero;
    final delta = _lastLanternTick == null ? Duration.zero : now - _lastLanternTick!;
    _lastLanternTick = now;
    _lanternElapsed += delta;
    lantern.tick(delta);
    setState(() {});
  }

  @override
  void didUpdateWidget(MazeBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pause menu can flip "fog mode" mid-level, so react rather than
    // only reading the flag once at construction.
    if (oldWidget.fogEnabled != widget.fogEnabled) _initFog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _moveController.dispose();
    _idleController.dispose();
    _bumpController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    _buildController.dispose();
    _dropController.dispose();
    _fogRevealController.dispose();
    _lanternController.dispose();
    _doorOpenController.dispose();
    _teleportController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded = state != AppLifecycleState.resumed;
    for (final controller in [_idleController, _pulseController, _sparkleController]) {
      if (backgrounded) {
        controller.stop();
      } else if (!controller.isAnimating) {
        controller.repeat(reverse: controller == _idleController);
      }
    }
    // The lantern's boost countdown must not keep draining while the app
    // is away, so it stops with everything else — and resumes without
    // counting the gap, since _lastLanternTick is re-based on resume.
    if (_lantern != null) {
      if (backgrounded) {
        _lanternController.stop();
      } else if (!_lanternController.isAnimating) {
        _lastLanternTick = null;
        _lanternController.repeat();
      }
    }
  }

  /// Particle physics piggyback on the pulse controller's own per-frame
  /// tick rather than a dedicated Ticker — it already fires every frame
  /// for the destination glow, so this avoids a second frame callback.
  void _onPulseTick() {
    if (_particles.isEmpty) return;
    final now = _pulseController.lastElapsedDuration ?? Duration.zero;
    final dt = _lastParticleTick == null ? 0.0 : (now - _lastParticleTick!).inMicroseconds / 1e6;
    _lastParticleTick = now;
    for (final particle in _particles) {
      particle.update(dt);
    }
    _particles.removeWhere((p) => !p.isAlive);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final direction = _directionForKey(event.logicalKey);
    if (direction == null) return KeyEventResult.ignored;
    _attemptMove(direction);
    return KeyEventResult.handled;
  }

  MazeDirection? _directionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return MazeDirection.north;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return MazeDirection.south;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return MazeDirection.west;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      return MazeDirection.east;
    }
    return null;
  }

  void _attemptMove(MazeDirection direction) {
    if (_isAnimatingMove || widget.controller.isWon) return;
    final previousStars = widget.controller.collectedStars.length;
    final moved = widget.controller.move(direction);
    if (moved) {
      _onSuccessfulMove(previousStars);
    } else {
      _triggerBump();
    }
  }

  void _handleDragPoint(Offset localPosition) {
    final now = DateTime.now();
    if (_lastDragStepAt != null &&
        now.difference(_lastDragStepAt!) < MazeConstants.dragStepThrottle) {
      return;
    }
    if (_isAnimatingMove || widget.controller.isWon) return;
    final target = _geometry.coordAt(localPosition);
    if (!widget.controller.maze.inBounds(target)) return;
    _lastDragStepAt = now;
    final previousStars = widget.controller.collectedStars.length;
    if (widget.controller.stepToward(widget.solver, target)) {
      _onSuccessfulMove(previousStars);
    }
  }

  void _handleTapToStep(Offset localPosition) {
    if (_isAnimatingMove || widget.controller.isWon) return;
    final target = _geometry.coordAt(localPosition);
    if (!widget.controller.maze.inBounds(target)) return;
    final previousStars = widget.controller.collectedStars.length;
    if (widget.controller.stepToward(widget.solver, target)) {
      _onSuccessfulMove(previousStars);
    }
  }

  void _onSuccessfulMove(int previousStarCount) {
    _startMoveTween();
    _fog?.reveal(
      playerPosition: widget.controller.playerPosition,
      mazeSize: widget.controller.maze.size,
      radiusOverride: _lantern?.radiusAt(_lanternElapsed),
    );
    if (_lantern?.collectAt(widget.controller.playerPosition) ?? false) {
      widget.onLightOrbCollected?.call();
    }
    _checkForKeyPickup();
    // A6 — the controller has already nudged the player back, so the shake
    // plus the caller's soft sound is all that's left to sell the contact.
    if (widget.controller.lastMoveHitCaravan) {
      _bumpController.forward(from: 0);
      widget.onCaravanBump?.call();
    }
    if (widget.controller.lastMoveCollectedFact) {
      widget.onFactCollected?.call();
    }
    _trail.add(_geometry.centerOf(widget.controller.playerPosition));
    while (_trail.length > MazeConstants.trailLength) {
      _trail.removeAt(0);
    }
    if (widget.controller.collectedStars.length > previousStarCount) {
      _particles.addAll(spawnMazeParticleBurst(
        origin: _geometry.centerOf(widget.controller.playerPosition),
        count: MazeConstants.starBurstParticleCount,
        colors: const [MazeColors.star, MazeColors.starSparkle],
        random: _particleRandom,
      ));
      widget.onStarCollected?.call(widget.controller.playerPosition);
    }
    if (_useZoom) _centerCameraOnPlayer();
    widget.onMoved?.call();
    if (widget.controller.isWon) {
      _particles.addAll(spawnMazeParticleBurst(
        origin: _geometry.centerOf(widget.controller.playerPosition),
        count: MazeConstants.winBurstMaxParticles,
        colors: const [MazeColors.star, MazeColors.starSparkle, MazeColors.wall],
        random: _particleRandom,
        speed: 220,
        size: 5,
        minLifeSeconds: 0.7,
        lifeSpreadSeconds: 0.5,
      ));
      widget.onWon?.call();
    }
    setState(() {});
  }

  /// A3 — the controller collects keys itself during [GameController.move],
  /// so a pickup shows up here as a new entry in its held-key set. Starts
  /// the matching door's opening swing.
  void _checkForKeyPickup() {
    final held = widget.controller.heldKeys;
    if (held.length == _lastKnownKeys.length) return;
    final gained = held.difference(_lastKnownKeys);
    _lastKnownKeys = held;
    if (gained.isEmpty) return;

    widget.onKeyCollected?.call();
    final unlocked =
        widget.controller.doors.doors.where((door) => gained.contains(door.keyKind)).firstOrNull;
    if (unlocked == null) return;
    _openingDoor = unlocked;
    _doorOpenController.forward(from: 0).then((_) {
      if (mounted) setState(() => _openingDoor = null);
    });
  }

  /// A4 — a small puff of dust where a slide skids to a stop. Capped like
  /// every other burst so the global particle budget still holds.
  void _spawnSlideDust(Offset at) {
    _particles.addAll(spawnMazeParticleBurst(
      origin: at,
      count: MazeConstants.slideDustParticleCount,
      colors: [MazeColors.sandStipple, MazeColors.sandFill],
      random: _particleRandom,
      speed: 70,
      size: 3,
      minLifeSeconds: 0.35,
      lifeSpreadSeconds: 0.25,
    ));
  }

  void _triggerBump() {
    widget.onBumped?.call();
    _bumpController.forward(from: 0);
  }

  void _startMoveTween() {
    final from = _moveAnimation?.value ??
        _initialPixelCenter ??
        _geometry.centerOf(widget.controller.playerPosition);
    final to = _geometry.centerOf(widget.controller.playerPosition);
    // A5 — a teleport must not be tweened across the board: the character
    // would glide through walls on the way. Instead it jumps straight to
    // the far tent and the fade/scale below sells the disappearance.
    if (widget.controller.lastTeleportFrom != null) {
      _isAnimatingMove = false;
      _moveAnimation = AlwaysStoppedAnimation(to);
      _teleportController.forward(from: 0);
      _trail.clear(); // the trail shouldn't draw a line across the maze
      _particles.addAll(spawnMazeParticleBurst(
        origin: to,
        count: MazeConstants.teleportArriveParticleCount,
        colors: [
          MazeColors.teleportGlowFor(
            widget.controller.movement.teleports?.pairAt(widget.controller.playerPosition)?.index ??
                0,
          ),
          MazeColors.starSparkle,
        ],
        random: _particleRandom,
        speed: 110,
        size: 3.5,
        minLifeSeconds: 0.4,
        lifeSpreadSeconds: 0.3,
      ));
      widget.onTeleported?.call();
      return;
    }
    // A4 — a sand slide covers several cells in one move, so it gets a
    // proportionally longer, decelerating tween (a skid) instead of the
    // single-step hop's duration, which would read as a teleport.
    final slideCells = widget.controller.lastSlidePath.length;
    final isSlide = slideCells > 1;
    _moveController.duration = isSlide
        ? MazeConstants.moveTweenDuration * (1 + (slideCells - 1) * 0.65)
        : MazeConstants.moveTweenDuration;
    _isAnimatingMove = true;
    _moveAnimation = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _moveController,
        curve: isSlide ? Curves.easeOutCubic : Curves.easeOut,
      ),
    );
    if (isSlide) _spawnSlideDust(to);
    _moveController.forward(from: 0).then((_) {
      _isAnimatingMove = false;
    });
  }

  void _centerCameraOnPlayer() {
    final playerCenter = _geometry.centerOf(widget.controller.playerPosition);
    final scale = _transformController.value.getMaxScaleOnAxis();
    final viewport = _lastViewportSize;
    if (viewport.isEmpty) return;
    final tx = -playerCenter.dx + viewport.width / 2 / scale;
    final ty = -playerCenter.dy + viewport.height / 2 / scale;
    _transformController.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(tx, ty, 0, 1);
  }

  double get _bumpShakeOffset {
    final t = _bumpController.value;
    if (t == 0 || t == 1) return 0;
    const amplitude = 6.0;
    return math.sin(t * math.pi * 4) * (1 - t) * amplitude;
  }

  double _bobOffsetFor(double cellSize) {
    if (!_isAnimatingMove) return 0;
    final t = _moveController.value;
    return -math.sin(t * math.pi) * cellSize * 0.08;
  }

  double _idleScale() => 1 + 0.04 * _idleController.value;

  void _ensureWallsPicture(MazeGeometry geometry) {
    final needsRebuild = !_wallsPictureFinal || _wallsPictureCellSize != geometry.cellSize;
    if (!needsRebuild) return;
    final progress = Curves.easeInOut.transform(_buildController.value);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final boardExtent = geometry.cellSize * widget.controller.maze.size;
    MazeWallsPainter(
      maze: widget.controller.maze,
      geometry: geometry,
      revealProgress: progress,
      wallColor: widget.environmentTheme?.wallTint ?? MazeColors.wall,
      glowColor: widget.environmentTheme?.glowTint ?? MazeColors.wallGlow,
    ).paint(canvas, Size(boardExtent, boardExtent));
    _wallsPicture = recorder.endRecording();
    _wallsPictureCellSize = geometry.cellSize;
    _wallsPictureFinal = _buildController.isCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maze = widget.controller.maze;
        final availableExtent = math.min(constraints.maxWidth, constraints.maxHeight);
        final boardExtent = math.min(availableExtent, MazeConstants.maxBoardSize);
        final naturalCellSize =
            maze.size == 0 ? MazeConstants.minCellSize : boardExtent / maze.size;
        _useZoom = naturalCellSize < MazeConstants.minCellSize;
        final cellSize = _useZoom ? MazeConstants.minCellSize : naturalCellSize;
        _geometry = MazeGeometry(cellSize: cellSize);
        _initialPixelCenter ??= _geometry.centerOf(maze.start);
        _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureWallsPicture(_geometry);

        final renderedExtent = cellSize * maze.size;
        final board = RepaintBoundary(
          child: SizedBox(
            width: renderedExtent,
            height: renderedExtent,
            child: _buildLayers(renderedExtent),
          ),
        );

        final content = _useZoom
            ? InteractiveViewer(
                transformationController: _transformController,
                minScale: 1,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(120),
                child: GestureDetector(
                  onTapUp: (details) => _handleTapToStep(details.localPosition),
                  child: board,
                ),
              )
            : Center(
                child: GestureDetector(
                  onPanDown: (details) => _handleDragPoint(details.localPosition),
                  onPanUpdate: (details) => _handleDragPoint(details.localPosition),
                  child: board,
                ),
              );

        return Focus(
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Semantics(
            label: _fog != null
                ? AppLocalizations.of(context)!.mazeBoardSemanticsFog
                : AppLocalizations.of(context)!.mazeBoardSemantics,
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildLayers(double extent) {
    final size = Size(extent, extent);
    return Stack(
      children: [
        if (_wallsPicture != null)
          RepaintBoundary(
            child: CustomPaint(size: size, painter: _PictureLayerPainter(_wallsPicture!)),
          ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _sparkleController]),
            builder: (context, _) => CustomPaint(
              size: size,
              painter: MazeDecorationsPainter(
                maze: widget.controller.maze,
                level: widget.controller.level,
                geometry: _geometry,
                pulsePhase: _pulseController.value,
                sparklePhase: _sparkleController.value,
                collectedStars: widget.controller.collectedStars,
                playerPosition: widget.controller.playerPosition,
                hintCells: widget.hintCells,
                lightOrbs: _lantern?.remainingOrbs ?? const {},
                oneWayArrows: widget.controller.movement.oneWayArrows,
                sandCells: widget.controller.movement.sandCells,
                teleportPairs: widget.controller.movement.teleports?.pairs ?? const [],
                factScrollCell:
                    widget.controller.factCollected ? null : widget.controller.factScrollCell,
              ),
            ),
          ),
        ),
        // A7 — shut passages draw in their own thin layer on top of the
        // cached wall picture, which is what lets that picture stay cached
        // across a toggle instead of being rebuilt.
        if (!(widget.controller.movement.shiftingWalls?.isEmpty ?? true))
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final walls = widget.controller.movement.shiftingWalls!;
                return CustomPaint(
                  size: size,
                  painter: ShiftingWallPainter(
                    geometry: _geometry,
                    closedEdges: walls.closedEdges,
                    warningEdges: walls.warningEdges,
                    warningPulse: _pulseController.value,
                  ),
                );
              },
            ),
          ),
        // A6 — moving obstacles sit above the static decorations, below the
        // fog (so an unseen caravan stays hidden) and below the character.
        if (!(widget.controller.movement.obstacles?.isEmpty ?? true))
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final obstacles = widget.controller.movement.obstacles!;
                return CustomPaint(
                  size: size,
                  painter: ObstaclePainter(
                    geometry: _geometry,
                    caravanCells: obstacles.caravanCells,
                    blockedCell: obstacles.blockedCell,
                    warningCell: obstacles.warningCell,
                    swirlPhase: _sparkleController.value,
                    warningPulse: _pulseController.value,
                  ),
                );
              },
            ),
          ),
        // A3 — doors and keys sit above the decorations but below the fog,
        // so a door you haven't found yet stays hidden in the dark.
        if (!widget.controller.doors.isEmpty)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _doorOpenController,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: DoorPainter(
                  geometry: _geometry,
                  lockedDoors: widget.controller.doors.lockedDoors,
                  remainingKeys: widget.controller.doors.remainingKeys,
                  openingDoor: _openingDoor,
                  openProgress: _doorOpenController.value,
                ),
              ),
            ),
          ),
        // A1 — fog sits above the walls/decorations it veils but below the
        // character, who is the one carrying the light.
        if (_fog != null)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_moveController, _fogRevealController, _lanternController]),
              builder: (context, _) => CustomPaint(
                size: size,
                painter: FogPainter(
                  geometry: _geometry,
                  mazeSize: widget.controller.maze.size,
                  playerCenter: _moveAnimation?.value ??
                      _initialPixelCenter ??
                      _geometry.centerOf(widget.controller.playerPosition),
                  rememberedCells: _fog!.rememberedCells,
                  // On a cave level the lantern owns the radius (flicker +
                  // orb boost); elsewhere it's the level's static fog radius.
                  lightRadiusInCells:
                      _lantern?.radiusAt(_lanternElapsed) ?? _fog!.config.visibilityRadius,
                  rememberedVeil: _fog!.config.rememberedOpacity,
                  hiddenVeil: _fog!.config.hiddenOpacity,
                  revealProgress: Curves.easeOut.transform(_fogRevealController.value),
                  destinationGlow: _lantern == null
                      ? null
                      : FogDestinationGlow(
                          center: _geometry.centerOf(widget.controller.maze.destination),
                          radiusInCells: MazeConstants.caveDestinationGlowRadius,
                          strength: MazeConstants.caveDestinationGlowStrength,
                        ),
                ),
              ),
            ),
          ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(
                [_moveController, _idleController, _bumpController, _dropController]),
            builder: (context, _) {
              final center = _moveAnimation?.value ??
                  _initialPixelCenter ??
                  _geometry.centerOf(widget.controller.playerPosition);
              final dropScale = Curves.easeOutBack.transform(_dropController.value).clamp(0.0, 1.2);
              // A5 — a tent jump pops the character back in at the far
              // end, so the arrival reads as materialising rather than as
              // an instant position swap.
              final teleportScale = _teleportController.isAnimating
                  ? Curves.easeOutBack.transform(_teleportController.value).clamp(0.0, 1.2)
                  : 1.0;
              return CustomPaint(
                size: size,
                painter: CharacterPainter(
                  center: center,
                  cellSize: _geometry.cellSize,
                  usesLightMarker: widget.controller.level.usesLightMarker,
                  bobOffset: _bobOffsetFor(_geometry.cellSize),
                  scale: _idleScale() * dropScale * teleportScale,
                  trail: List.of(_trail),
                  shakeOffset: _bumpShakeOffset,
                ),
              );
            },
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(size: size, painter: ParticlePainter(particles: _particles)),
        ),
      ],
    );
  }
}

class _PictureLayerPainter extends CustomPainter {
  const _PictureLayerPainter(this.picture);

  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(picture);

  @override
  bool shouldRepaint(covariant _PictureLayerPainter oldDelegate) => oldDelegate.picture != picture;
}
