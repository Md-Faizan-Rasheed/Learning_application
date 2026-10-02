import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_constants.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_levels.dart';
import '../logic/game_controller.dart';
import '../logic/maze_generator.dart';
import '../logic/maze_solver.dart';
import '../logic/collectibles/fact_scroll_placement.dart';
import '../logic/mechanics/doors_and_keys.dart';
import '../logic/mechanics/movement_rules.dart';
import '../logic/mechanics/obstacle_field.dart';
import '../logic/mechanics/teleport_network.dart';
import '../models/maze_cell.dart';
import '../models/maze_direction.dart';
import '../data/maze_environments.dart';
import '../logic/environment/ambient_particle_field.dart';
import '../models/maze_environment.dart';
import '../models/maze_level.dart';
import '../models/maze_mechanics.dart';
import '../models/maze_progress.dart';
import '../painters/background_pattern_painter.dart';
import '../painters/environment_painter.dart';
import 'hud.dart';
import 'maze_board.dart';
import 'mechanic_tooltip_banner.dart';
import 'pause_menu.dart';
import 'responsive/maze_breakpoints.dart';
import 'win_card.dart';

/// The playable screen for one level: background, HUD, the interactive
/// board, and the hint/pause/win flows around it. Pushed by
/// LevelSelectScreen (added alongside this file) and always exactly one
/// level deep in the navigation stack above it — "Next Level" uses
/// `pushReplacement` (not `push`) specifically so the stack never grows,
/// which keeps "pop back to level select" a single, reliable
/// `Navigator.pop()` regardless of how many levels/replays happened in
/// between.
class MazeGameScreen extends StatefulWidget {
  const MazeGameScreen({
    super.key,
    required this.level,
    required this.isLastLevel,
    required this.initialProgress,
    required this.onLevelCompleted,
    required this.onProgressChanged,
  });

  final MazeLevel level;
  final bool isLastLevel;
  final MazeProgress initialProgress;

  /// Called the moment a level is won (before the player picks anything
  /// from the win card), so progress is never lost to a dropped navigation
  /// choice. `timeSeconds` is the finish time actually achieved.
  final void Function(int levelId, int stars, int timeSeconds) onLevelCompleted;

  /// Called whenever the pause menu's settings toggles change, so the
  /// ancestor LevelSelectScreen's copy of [MazeProgress] (the one that
  /// actually gets persisted) stays in sync with whatever was changed here.
  final ValueChanged<MazeProgress> onProgressChanged;

  @override
  State<MazeGameScreen> createState() => _MazeGameScreenState();
}

class _MazeGameScreenState extends State<MazeGameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _generator = MazeGenerator();
  static const _solver = MazeSolver();

  late MazeGenerationResult _maze;
  late GameController _controller;
  late MazeProgress _progress;
  int _playthroughId = 0;
  Timer? _tickTimer;
  Timer? _hintTimer;
  List<MazeCoord> _hintCells = const [];
  bool _pauseDialogOpen = false;
  bool _wonHandled = false;
  late bool _showControlHint;
  late List<MazeMechanicTooltip> _pendingTooltips;

  /// B2 — this level's atmosphere, and the ambient particle field +
  /// drifting clock behind it. Both are fixed for the level's lifetime
  /// (same level id never changes mid-playthrough), computed once here
  /// rather than every build.
  late final MazeEnvironmentTheme _environment = mazeEnvironmentFor(widget.level.id);
  late final AmbientParticleField _ambientField =
      AmbientParticleField(type: _environment.particleType, seed: widget.level.id);
  late final AnimationController _ambientController =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addListener(_onAmbientTick)
        ..repeat();
  Duration _ambientElapsed = Duration.zero;
  Duration? _lastAmbientTick;

  /// Advances [_ambientElapsed] by the real time between frames — the
  /// same elapsed-duration-diffing pattern maze_board.dart's cave lantern
  /// uses, rather than reading the controller's own wrapped 0..1 value,
  /// since the particle math needs ever-increasing seconds, not a cycling
  /// fraction.
  void _onAmbientTick() {
    final now = _ambientController.lastElapsedDuration ?? Duration.zero;
    final delta = _lastAmbientTick == null ? Duration.zero : now - _lastAmbientTick!;
    _lastAmbientTick = now;
    _ambientElapsed += delta;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress = widget.initialProgress;
    _showControlHint = !_progress.firstPlayHintShown;
    // A8 — queued in MazeMechanicTooltip's declared order, so a level that
    // introduces more than one mechanic at once (e.g. sand + the
    // sandstorm) always presents them in the same order.
    _pendingTooltips = widget.level.mechanics.introducedTooltips
        .difference(_progress.seenMechanicTooltips)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (_pendingTooltips.isNotEmpty) {
      // Marked seen immediately (not deferred to dismissal or first move),
      // so "never shown twice" holds even if the player quits mid-level
      // without ever tapping the banner away.
      final updated = _progress.copyWith(
        seenMechanicTooltips: {..._progress.seenMechanicTooltips, ..._pendingTooltips},
      );
      _progress = updated;
      widget.onProgressChanged(updated);
    }
    MazeAudioService.instance.enabled = _progress.soundEnabled;
    _startLevel();
  }

  void _startLevel() {
    _maze = _generator.generate(
      size: widget.level.gridSize,
      seed: widget.level.seed,
      extraLoopCount: widget.level.extraLoopCount,
    );
    final doors = _buildDoors();
    final movement = _buildMovementRules(doors);
    _controller = GameController(
      maze: _maze,
      level: widget.level,
      doors: doors,
      movement: movement,
      factScrollCell: placeFactScroll(
        maze: _maze,
        reserved: {
          ...movement.sandCells,
          ...movement.oneWayArrows.keys,
          ...?movement.teleports?.tentCells,
          ...?doors?.keys.keys,
        },
      ),
    );
    _hintCells = const [];
    _wonHandled = false;
    _playthroughId++;
    _hintTimer?.cancel();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _controller.tick(const Duration(milliseconds: 200));
      if (mounted) setState(() {});
    });
  }

  /// A3 — doors are placed from the level's own solution path, and
  /// DoorsAndKeys.place proves the result is still finishable before
  /// returning it, so a level can never ship a softlocked door layout.
  DoorsAndKeys? _buildDoors() {
    final config = widget.level.mechanics.doors;
    if (config == null) return null;
    final path = _solver.shortestPath(_maze, _maze.start, _maze.destination) ?? const [];
    return DoorsAndKeys.place(
      maze: _maze,
      solutionPath: path,
      doorCount: config.doorCount,
    );
  }

  /// A4 — sand first, then arrows placed around it, with each placement
  /// step only keeping candidates that leave the level escapable from
  /// every reachable cell (MazeMovementRules.isAlwaysEscapable). That
  /// ordering matters: an arrow is only safe relative to the sand that
  /// already exists, since a slide can carry the player somewhere a plain
  /// step never would.
  MazeMovementRules _buildMovementRules(DoorsAndKeys? doors) {
    final mechanics = widget.level.mechanics;
    if (!mechanics.hasSand &&
        !mechanics.hasOneWay &&
        !mechanics.hasTeleports &&
        !mechanics.hasCaravans &&
        !mechanics.hasSandstorm &&
        !mechanics.hasShiftingWalls) {
      return MazeMovementRules(maze: _maze, doors: doors);
    }
    final path = _solver.shortestPath(_maze, _maze.start, _maze.destination) ?? const [];

    final sand = mechanics.sand == null
        ? const <MazeCoord>{}
        : MazeMovementRules.placeSand(
            maze: _maze,
            solutionPath: path,
            patchCount: mechanics.sand!.patchCount,
            patchLength: mechanics.sand!.patchLength,
            doors: doors,
          );

    final arrows = mechanics.oneWay == null
        ? const <MazeCoord, MazeDirection>{}
        : MazeMovementRules.placeOneWays(
            maze: _maze,
            solutionPath: path,
            tileCount: mechanics.oneWay!.tileCount,
            doors: doors,
            sandCells: sand,
          );

    final teleports = _buildTeleports(
      doors: doors,
      solutionPath: path,
      reserved: {...sand, ...arrows.keys},
    );

    return MazeMovementRules(
      maze: _maze,
      doors: doors,
      teleports: teleports,
      shiftingWalls: mechanics.shiftingWalls == null
          ? null
          : MazeMovementRules.placeShiftingWalls(
              maze: _maze,
              solutionPath: path,
              toggleCount: mechanics.shiftingWalls!.toggleCount,
              interval: mechanics.shiftingWalls!.interval,
              warningLead: mechanics.shiftingWalls!.warningLead,
              doors: doors,
              teleports: teleports,
              oneWayArrows: arrows,
              sandCells: sand,
            ),
      obstacles: _buildObstacles(
        solutionPath: path,
        reserved: {
          ...sand,
          ...arrows.keys,
          ...?teleports?.tentCells,
          ...?doors?.keys.keys,
        },
      ),
      oneWayArrows: arrows,
      sandCells: sand,
    );
  }

  /// A6 — caravans need a straight corridor and the sandstorm needs plain
  /// two-exit cells, both taken from the solution path and both avoiding
  /// everything the other mechanics already claimed. A sandstorm closure
  /// always clears again, so unlike doors or arrows it needs no solvability
  /// proof — it can only ever cost the player time.
  ObstacleField? _buildObstacles({
    required List<MazeCoord> solutionPath,
    required Set<MazeCoord> reserved,
  }) {
    final mechanics = widget.level.mechanics;
    if (!mechanics.hasCaravans && !mechanics.hasSandstorm) return null;

    final caravans = mechanics.caravans == null
        ? const <CaravanRoute>[]
        : ObstacleField.placeCaravans(
            maze: _maze,
            solutionPath: solutionPath,
            caravanCount: mechanics.caravans!.caravanCount,
            cycle: mechanics.caravans!.cycle,
            reserved: reserved,
          );

    final sandstorm = mechanics.sandstorm == null
        ? null
        : ObstacleField.placeSandstorm(
            maze: _maze,
            solutionPath: solutionPath,
            config: mechanics.sandstorm!,
            reserved: {
              ...reserved,
              for (final route in caravans) ...route.segment,
            },
          );

    return ObstacleField(caravans: caravans, sandstorm: sandstorm);
  }

  /// A5 — tents are placed last, so they can avoid every cell the other
  /// mechanics already claimed, and each candidate pair is rejected unless
  /// it leaves at least the configured fraction of the original journey
  /// intact (TeleportNetwork.wouldBeTrivialShortcut).
  TeleportNetwork? _buildTeleports({
    required DoorsAndKeys? doors,
    required List<MazeCoord> solutionPath,
    required Set<MazeCoord> reserved,
  }) {
    final config = widget.level.mechanics.teleports;
    if (config == null) return null;
    return TeleportNetwork.place(
      maze: _maze,
      solutionLength: solutionPath.isEmpty ? 0 : solutionPath.length - 1,
      pairCount: config.pairCount,
      minShortcutFraction: config.minShortcutFraction,
      cooldown: config.cooldown,
      reserved: {...reserved, ...?doors?.keys.keys},
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _hintTimer?.cancel();
    _ambientController.dispose();
    super.dispose();
  }

  /// B2 — "disable via a reduce motion setting (also honor the system
  /// accessibility reduce-motion flag)": either source freezes the ambient
  /// drift (the backdrop still renders, just at a fixed moment) without
  /// touching any other animation in the level.
  void _syncAmbientMotion(bool reduceMotion) {
    if (reduceMotion) {
      if (_ambientController.isAnimating) _ambientController.stop();
    } else if (!_ambientController.isAnimating) {
      _ambientController.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pauseDialogOpen) return; // the pause dialog owns pause/resume while it's open
    if (state == AppLifecycleState.resumed) {
      _controller.resume();
    } else {
      _controller.pause();
    }
  }

  void _onHint() {
    final cells = _controller.useHint(_solver);
    if (cells.isEmpty) return;
    MazeAudioService.instance.playHint();
    _hintTimer?.cancel();
    setState(() => _hintCells = cells);
    _hintTimer = Timer(MazeConstants.hintHighlightDuration, () {
      if (mounted) setState(() => _hintCells = const []);
    });
  }

  void _onStep() {
    MazeAudioService.instance.playStep();
    if (_showControlHint) {
      setState(() => _showControlHint = false);
      final updated = _progress.copyWith(firstPlayHintShown: true);
      _progress = updated;
      widget.onProgressChanged(updated);
    }
  }

  void _onBumped() {
    if (_progress.hapticsEnabled) HapticFeedback.lightImpact();
    MazeAudioService.instance.playBump();
  }

  void _onStarCollected(_) {
    if (_progress.hapticsEnabled) HapticFeedback.mediumImpact();
    MazeAudioService.instance.playStar();
  }

  void _onLightOrbCollected() {
    if (_progress.hapticsEnabled) HapticFeedback.lightImpact();
    // Reuses the hint cue rather than introducing a seventh sound slot for
    // a mechanic that only appears on two levels; both read as "something
    // just helped you".
    MazeAudioService.instance.playHint();
  }

  void _onKeyCollected() {
    if (_progress.hapticsEnabled) HapticFeedback.mediumImpact();
    MazeAudioService.instance.playStar();
  }

  void _onTeleported() {
    if (_progress.hapticsEnabled) HapticFeedback.mediumImpact();
    MazeAudioService.instance.playHint();
  }

  /// A6 — deliberately the same soft cue as walking into a wall, because
  /// that's what a caravan is: an obstruction, not a failure.
  void _onCaravanBump() {
    if (_progress.hapticsEnabled) HapticFeedback.lightImpact();
    MazeAudioService.instance.playBump();
  }

  /// B4 — persisted immediately, like every other one-time unlock in this
  /// feature, so the Library screen reflects it even if the player quits
  /// mid-level right after finding it.
  void _onFactCollected() {
    if (_progress.hapticsEnabled) HapticFeedback.mediumImpact();
    MazeAudioService.instance.playStar();
    final updated = _progress.copyWith(
      collectedFactLevelIds: {..._progress.collectedFactLevelIds, widget.level.id},
    );
    _progress = updated;
    widget.onProgressChanged(updated);
  }

  Future<void> _onPause() async {
    MazeAudioService.instance.playButtonTap();
    _pauseDialogOpen = true;
    _controller.pause();
    final (action, newProgress) = await showMazePauseMenu(context, progress: _progress);
    _pauseDialogOpen = false;
    MazeAudioService.instance.enabled = newProgress.soundEnabled;
    setState(() => _progress = newProgress);
    widget.onProgressChanged(newProgress);

    switch (action) {
      case MazePauseAction.resume:
        _controller.resume();
      case MazePauseAction.restart:
        setState(_startLevel);
      case MazePauseAction.levelSelect:
        if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _onWon() async {
    if (_wonHandled) return;
    _wonHandled = true;
    _tickTimer?.cancel();
    if (_progress.hapticsEnabled) HapticFeedback.heavyImpact();
    MazeAudioService.instance.playWin();
    final stars = _controller.rating.index + 1;
    widget.onLevelCompleted(widget.level.id, stars, _controller.elapsed.inSeconds);

    // Gives the board's own win-moment particle burst a beat to read before
    // the card slides up and covers it.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final action = await showMazeWinCard(
      context,
      level: widget.level,
      controller: _controller,
      isLastLevel: widget.isLastLevel,
    );
    if (!mounted) return;

    switch (action) {
      case MazeWinAction.replay:
        setState(_startLevel);
      case MazeWinAction.nextLevel:
        final nextLevel = kMazeLevels.firstWhere((l) => l.id == widget.level.id + 1);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MazeGameScreen(
              level: nextLevel,
              isLastLevel: nextLevel.id == kMazeLevels.length,
              initialProgress: _progress,
              onLevelCompleted: widget.onLevelCompleted,
              onProgressChanged: widget.onProgressChanged,
            ),
          ),
        );
      case MazeWinAction.levelSelect:
      case null:
        if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _hud(Axis axis) {
    final t = AppLocalizations.of(context)!;
    final levelText = mazeLevelTextFor(t, widget.level.id);
    return MazeHud(
      levelName: t.mazeLevelRoute(levelText.character, levelText.destination),
      elapsed: _controller.elapsed,
      starsCollected: _controller.collectedStars.length,
      hintsRemaining: _controller.hintsRemaining,
      axis: axis,
      heldKeys: _controller.heldKeys,
      onBack: () {
        MazeAudioService.instance.playButtonTap();
        Navigator.of(context).pop();
      },
      onHint: _onHint,
      onPause: _onPause,
    );
  }

  Widget _boardArea() {
    final t = AppLocalizations.of(context)!;
    final levelText = mazeLevelTextFor(t, widget.level.id);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: MazeBoardWidget(
            key: ValueKey(_playthroughId),
            controller: _controller,
            solver: _solver,
            environmentTheme: _environment,
            fogEnabled: _progress.fogEnabled,
            hintCells: _hintCells,
            onMoved: _onStep,
            onBumped: _onBumped,
            onStarCollected: _onStarCollected,
            onLightOrbCollected: _onLightOrbCollected,
            onKeyCollected: _onKeyCollected,
            onTeleported: _onTeleported,
            onCaravanBump: _onCaravanBump,
            onFactCollected: _onFactCollected,
            onWon: _onWon,
          ),
        ),
        if (_pendingTooltips.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Center(
              child: MazeMechanicTooltipBanner(
                queue: _pendingTooltips,
                onDismissedAll: () => setState(() => _pendingTooltips = const []),
              ),
            ),
          ),
        if (_showControlHint)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t.mazeControlHint(levelText.character),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _progress.reduceMotionEnabled || MediaQuery.of(context).disableAnimations;
    _syncAmbientMotion(reduceMotion);
    // B2 — a tiny, bounded shift so distant/near parallax layers read as
    // having real depth as the player crosses the board, never enough to
    // look like scrolling.
    final parallaxShift =
        _maze.size <= 1 ? 0.0 : (_controller.playerPosition.col / (_maze.size - 1)) * 2 - 1;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _environment.backgroundGradient,
                ),
              ),
              child: CustomPaint(
                painter: EnvironmentPainter(
                  layers: _environment.parallaxLayers,
                  particles: _ambientField.particlesAt(_ambientElapsed.inMilliseconds / 1000),
                  parallaxShift: parallaxShift,
                ),
                child: CustomPaint(painter: const BackgroundPatternPainter(), child: Container()),
              ),
            ),
          ),
          SafeArea(
            child: MazeResponsive(
              builder: (context, size, orientation) {
                // A side-panel HUD only once there's real width to spare for
                // it alongside a full-size board — a landscape phone (medium,
                // landscape) is still too cramped for this, so it keeps the
                // top-bar layout; only medium+ in landscape (small tablets
                // and up) or expanded screens of any shape get the sidebar.
                final useSidePanel =
                    orientation == Orientation.landscape && size != MazeScreenSize.compact;
                if (!useSidePanel) {
                  return Column(
                    children: [
                      _hud(Axis.horizontal),
                      Expanded(child: _boardArea()),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: MazeConstants.hudSidePanelWidth, child: _hud(Axis.vertical)),
                    Expanded(child: _boardArea()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
