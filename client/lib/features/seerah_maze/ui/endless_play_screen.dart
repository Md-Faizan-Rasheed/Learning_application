import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../data/endless_run_repository.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_progress_repository.dart';
import '../logic/endless/endless_round_config.dart';
import '../logic/game_controller.dart';
import '../logic/maze_generator.dart';
import '../logic/maze_solver.dart';
import '../models/endless_best_run.dart';
import '../models/maze_cell.dart';
import '../models/maze_character_skin.dart';
import '../models/maze_level.dart';
import '../painters/background_pattern_painter.dart';
import 'hud.dart';
import 'maze_board.dart';

/// C3 — Endless mode: a chain of back-to-back generated mazes that never
/// returns to a menu between rounds. There's no fixed win — a shared time
/// bank (started at [endlessStartingBank], topped up by each round's own
/// [EndlessRoundConfig.timeBonus]) counts down continuously, and the run
/// ends the moment it reaches zero (or the player chooses to end it
/// early from the pause menu or the back button). Rounds themselves are
/// plain, like the Daily puzzle — no doors/sand/mechanics — since the
/// challenge here is speed and chaining, not a per-round gimmick.
///
/// [random] and [repository] are injectable so tests can fix the maze
/// sequence and substitute a fake save, instead of this screen reading
/// `Random()` / real SharedPreferences directly.
class EndlessPlayScreen extends StatefulWidget {
  EndlessPlayScreen({
    super.key,
    Random? random,
    EndlessRunRepository? repository,
    MazeProgressRepository? progressRepository,
  })  : random = random ?? Random(),
        repository = repository ?? const EndlessRunRepository(),
        progressRepository = progressRepository ?? const MazeProgressRepository();

  final Random random;
  final EndlessRunRepository repository;

  /// D3 — read-only here, just to pick up the player's selected cosmetic
  /// skin; this screen never writes campaign progress.
  final MazeProgressRepository progressRepository;

  @override
  State<EndlessPlayScreen> createState() => _EndlessPlayScreenState();
}

class _EndlessPlayScreenState extends State<EndlessPlayScreen> {
  static const _generator = MazeGenerator();
  static const _solver = MazeSolver();

  late MazeGenerationResult _maze;
  late GameController _controller;
  int _round = 1;
  Duration _bank = endlessStartingBank;
  Timer? _tickTimer;
  Timer? _hintTimer;
  List<MazeCoord> _hintCells = const [];
  bool _paused = false;
  bool _runOverHandled = false;
  MazeCharacterSkinDef _skin = mazeCharacterSkinDefFor(MazeCharacterSkinId.traveler);

  @override
  void initState() {
    super.initState();
    _loadSkin();
    _startRound(_round);
    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_runOverHandled || _paused) return;
      const delta = Duration(milliseconds: 200);
      _controller.tick(delta);
      _bank -= delta;
      if (_bank <= Duration.zero) {
        _bank = Duration.zero;
        MazeAudioService.instance.playBump();
        unawaited(_finishRun());
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _startRound(int round) {
    final config = endlessConfigForRound(round);
    final seed = widget.random.nextInt(1 << 31);
    _maze = _generator.generate(
      size: config.gridSize,
      seed: seed,
      extraLoopCount: config.extraLoopCount,
    );
    _controller = GameController(
      maze: _maze,
      level: MazeLevel(
        id: 0,
        gridSize: config.gridSize,
        seed: seed,
        extraLoopCount: config.extraLoopCount,
        starTimeThreshold: const Duration(minutes: 10),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      ),
    );
    _hintCells = const [];
  }

  Future<void> _loadSkin() async {
    final progress = await widget.progressRepository.load();
    if (!mounted) return;
    setState(() => _skin = mazeCharacterSkinDefFor(progress.selectedSkin));
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

  void _onMoved() => MazeAudioService.instance.playStep();
  void _onBumped() => MazeAudioService.instance.playBump();

  Future<void> _onPause() async {
    MazeAudioService.instance.playButtonTap();
    _paused = true;
    _controller.pause();
    final t = AppLocalizations.of(context)!;
    var endRun = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazePausedTitle),
        actions: [
          TextButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              endRun = true;
              Navigator.of(context).pop();
            },
            child: Text(t.mazeEndlessEndRunButton),
          ),
          FilledButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              Navigator.of(context).pop();
            },
            child: Text(t.mazeResumeButton),
          ),
        ],
      ),
    );
    if (endRun) {
      await _finishRun();
      return;
    }
    _paused = false;
    _controller.resume();
  }

  /// Fired once per round clear — tops up the bank, then (after a short
  /// pause so the win burst is visible) moves straight into the next
  /// round without any intermediate dialog, since the point of this mode
  /// is that it never stops to ask.
  void _onWon() {
    if (_runOverHandled) return;
    MazeAudioService.instance.playWin();
    HapticFeedback.heavyImpact();
    final bonus = endlessConfigForRound(_round).timeBonus;
    setState(() {
      _bank += bonus;
      _round += 1;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _runOverHandled) return;
      setState(() => _startRound(_round));
    });
  }

  Future<void> _finishRun() async {
    if (_runOverHandled) return;
    _runOverHandled = true;
    _tickTimer?.cancel();
    final roundsCleared = _round - 1;
    final best = await widget.repository.load();
    final isNewBest = roundsCleared > best.bestRoundsCleared;
    if (isNewBest) {
      await widget.repository.save(EndlessBestRun(bestRoundsCleared: roundsCleared));
    }
    if (!mounted) return;
    await _showRunOverDialog(roundsCleared, isNewBest);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showRunOverDialog(int roundsCleared, bool isNewBest) async {
    final t = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazeEndlessRunOverTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.mazeEndlessRoundsClearedNote(roundsCleared), textAlign: TextAlign.center),
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Text(
                t.mazeEndlessNewBestNote,
                style: const TextStyle(fontWeight: FontWeight.w800, color: MazeColors.star),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              Navigator.of(context).pop();
            },
            child: Text(t.mazeLibraryCloseButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: MazeColors.background,
                ),
              ),
              child: CustomPaint(painter: const BackgroundPatternPainter(), child: Container()),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                MazeHud(
                  levelName: t.mazeEndlessRoundLabel(_round),
                  elapsed: _controller.elapsed,
                  starsCollected: _controller.collectedStars.length,
                  hintsRemaining: _controller.hintsRemaining,
                  bankRemaining: _bank,
                  onBack: () {
                    MazeAudioService.instance.playButtonTap();
                    unawaited(_finishRun());
                  },
                  onHint: _onHint,
                  onPause: _onPause,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MazeBoardWidget(
                      key: ValueKey(_round),
                      controller: _controller,
                      solver: _solver,
                      hintCells: _hintCells,
                      onMoved: _onMoved,
                      onBumped: _onBumped,
                      onWon: _onWon,
                      characterFillColor: _skin.fillColor,
                      characterTrailColor: _skin.trailColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
