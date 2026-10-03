import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../data/daily_maze_repository.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_progress_repository.dart';
import '../logic/daily/daily_seed.dart';
import '../logic/daily/daily_streak_calculator.dart';
import '../logic/game_controller.dart';
import '../logic/maze_generator.dart';
import '../logic/maze_solver.dart';
import '../models/maze_cell.dart';
import '../models/maze_character_skin.dart';
import '../models/maze_level.dart';
import '../painters/background_pattern_painter.dart';
import 'hud.dart';
import 'maze_board.dart';

/// C2 — plays today's daily maze.
///
/// Deliberately its own small screen rather than a reuse of
/// MazeGameScreen: that screen's text/environment/mechanics all key off
/// one of the 10 fixed campaign level ids (1-10), none of which a daily
/// puzzle has. The daily puzzle is plain by design — no doors, sand,
/// mechanics or collectible fact, so every player's "maze for today" is
/// exactly as hard as the generator and nothing else, and the whole
/// screen stays this much smaller than the campaign one.
///
/// [nowUtc] and [repository] are injectable so tests can fix "today" and
/// substitute a fake save, instead of this screen reading the system
/// clock / real SharedPreferences directly.
class DailyMazePlayScreen extends StatefulWidget {
  // Not const: the nowUtc ?? _unset fallback needs a runtime sentinel,
  // since DateTime has no usable const "unset" value to default to.
  DailyMazePlayScreen({
    super.key,
    DateTime? nowUtc,
    DailyMazeRepository? repository,
    MazeProgressRepository? progressRepository,
  })  : nowUtc = nowUtc ?? _unset,
        repository = repository ?? const DailyMazeRepository(),
        progressRepository = progressRepository ?? const MazeProgressRepository();

  final DateTime nowUtc;
  final DailyMazeRepository repository;

  /// D3 — read-only here, just to pick up the player's selected cosmetic
  /// skin; this screen never writes campaign progress.
  final MazeProgressRepository progressRepository;

  // A real DateTime.now() call has to happen somewhere; doing it here as
  // a lazily-resolved default (rather than evaluating it once at import
  // time) keeps "today" genuinely live for production callers while
  // still letting a test pass a fixed value through the constructor.
  static final DateTime _unset = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get _effectiveNowUtc => identical(nowUtc, _unset) ? DateTime.now().toUtc() : nowUtc;

  static const int gridSize = 10;
  static const int extraLoopCount = 3;

  @override
  State<DailyMazePlayScreen> createState() => _DailyMazePlayScreenState();
}

class _DailyMazePlayScreenState extends State<DailyMazePlayScreen> {
  static const _generator = MazeGenerator();
  static const _solver = MazeSolver();

  late MazeGenerationResult _maze;
  late GameController _controller;
  Timer? _tickTimer;
  Timer? _hintTimer;
  List<MazeCoord> _hintCells = const [];
  bool _wonHandled = false;
  MazeCharacterSkinDef _skin = mazeCharacterSkinDefFor(MazeCharacterSkinId.traveler);

  @override
  void initState() {
    super.initState();
    _loadSkin();
    final seed = dailySeedFor(widget._effectiveNowUtc);
    _maze = _generator.generate(
      size: DailyMazePlayScreen.gridSize,
      seed: seed,
      extraLoopCount: DailyMazePlayScreen.extraLoopCount,
    );
    _controller = GameController(
      maze: _maze,
      level: MazeLevel(
        id: 0,
        gridSize: DailyMazePlayScreen.gridSize,
        seed: seed,
        extraLoopCount: DailyMazePlayScreen.extraLoopCount,
        starTimeThreshold: const Duration(minutes: 3),
        destinationKind: MazeDestinationKind.kaaba,
        usesLightMarker: false,
      ),
    );
    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _controller.tick(const Duration(milliseconds: 200));
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSkin() async {
    final progress = await widget.progressRepository.load();
    if (!mounted) return;
    setState(() => _skin = mazeCharacterSkinDefFor(progress.selectedSkin));
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
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

  /// A minimal pause, since the daily puzzle has no settings worth a
  /// full dialog of toggles (no fog/doors/ghost here to configure) — just
  /// stop the clock and let the player resume when ready.
  Future<void> _onPause() async {
    MazeAudioService.instance.playButtonTap();
    _controller.pause();
    final t = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazePausedTitle),
        actions: [
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
    _controller.resume();
  }

  Future<void> _onWon() async {
    if (_wonHandled) return;
    _wonHandled = true;
    _tickTimer?.cancel();
    MazeAudioService.instance.playWin();
    HapticFeedback.heavyImpact();

    final stored = await widget.repository.load();
    final result = recordDailyCompletion(progress: stored, nowUtc: widget._effectiveNowUtc);
    await widget.repository.save(result.progress);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _showResultDialog(result.outcome, result.progress.currentStreak);
    if (!mounted) return;
    // Back to DailyMazeScreen, using this State's own context — stable
    // for the screen's whole lifetime, unlike the dialog's own context
    // above, which stops being usable the moment the dialog closes.
    Navigator.of(context).pop();
  }

  Future<void> _showResultDialog(DailyStreakOutcome outcome, int streak) async {
    final t = AppLocalizations.of(context)!;
    final minutes = _controller.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _controller.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazeDailySolvedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes:$seconds', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              outcome == DailyStreakOutcome.alreadyCountedToday
                  ? t.mazeDailyPracticeNote
                  : t.mazeDailyStreakNote(streak),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              // Pops only the dialog's own route, using its own context —
              // the screen itself is popped separately below, from the
              // screen's own stable context, once this await resolves.
              // Reusing this same (dialog) context for a second pop isn't
              // reliable: Flutter may already be tearing the dialog's
              // element down by the time that second call runs.
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
                  levelName: t.mazeDailyTitle,
                  elapsed: _controller.elapsed,
                  starsCollected: _controller.collectedStars.length,
                  hintsRemaining: _controller.hintsRemaining,
                  onBack: () {
                    MazeAudioService.instance.playButtonTap();
                    Navigator.of(context).pop();
                  },
                  onHint: _onHint,
                  onPause: _onPause,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MazeBoardWidget(
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
