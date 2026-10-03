import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_progress_repository.dart';
import '../logic/game_controller.dart';
import '../logic/maze_generator.dart';
import '../logic/maze_solver.dart';
import '../models/maze_character_skin.dart';
import '../models/maze_direction.dart';
import '../models/maze_level.dart';
import 'direction_pad.dart';
import 'maze_board.dart';
import 'responsive/maze_breakpoints.dart';

/// C6 — two players, one device, one maze: identical layouts (same
/// generated maze, same start/destination) raced simultaneously by two
/// independent GameControllers, each driven by its own on-screen D-pad
/// rather than the keyboard — neither board needs to hold keyboard focus,
/// which lets both move at once (see MazeBoardWidget.onMoveRequesterReady).
/// Deliberately plain, like the Daily puzzle: no mechanics, no
/// persistence — this is a head-to-head for fun, not a tracked mode.
class TwoPlayerRaceScreen extends StatefulWidget {
  TwoPlayerRaceScreen({super.key, Random? random, MazeProgressRepository? progressRepository})
      : random = random ?? Random(),
        progressRepository = progressRepository ?? const MazeProgressRepository();

  final Random random;

  /// D3 — read-only here, just to pick up the player's selected cosmetic
  /// skin (shared by both players — one local device, one account).
  final MazeProgressRepository progressRepository;

  static const int gridSize = 10;
  static const int extraLoopCount = 3;

  @override
  State<TwoPlayerRaceScreen> createState() => _TwoPlayerRaceScreenState();
}

class _TwoPlayerRaceScreenState extends State<TwoPlayerRaceScreen> {
  static const _generator = MazeGenerator();
  static const _solver = MazeSolver();

  late MazeGenerationResult _maze;
  late GameController _p1;
  late GameController _p2;
  Timer? _tickTimer;
  bool _paused = false;
  bool _raceOverHandled = false;
  // Bumped by every _startRace() call so each MazeBoardWidget gets a new
  // key — forcing a full remount (fresh animation controllers, trail,
  // geometry) for the new maze/controllers, rather than leaving Flutter
  // to decide what a same-position controller swap should do.
  int _raceId = 0;
  void Function(MazeDirection)? _p1Mover;
  void Function(MazeDirection)? _p2Mover;
  MazeCharacterSkinDef _skin = mazeCharacterSkinDefFor(MazeCharacterSkinId.traveler);

  @override
  void initState() {
    super.initState();
    _loadSkin();
    _startRace();
    _startTicking();
  }

  Future<void> _loadSkin() async {
    final progress = await widget.progressRepository.load();
    if (!mounted) return;
    setState(() => _skin = mazeCharacterSkinDefFor(progress.selectedSkin));
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startTicking() {
    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_paused || _raceOverHandled) return;
      const delta = Duration(milliseconds: 200);
      _p1.tick(delta);
      _p2.tick(delta);
      if (mounted) setState(() {});
    });
  }

  void _startRace() {
    final seed = widget.random.nextInt(1 << 31);
    _maze = _generator.generate(
      size: TwoPlayerRaceScreen.gridSize,
      seed: seed,
      extraLoopCount: TwoPlayerRaceScreen.extraLoopCount,
    );
    final level = MazeLevel(
      id: 0,
      gridSize: TwoPlayerRaceScreen.gridSize,
      seed: seed,
      extraLoopCount: TwoPlayerRaceScreen.extraLoopCount,
      starTimeThreshold: const Duration(minutes: 10),
      destinationKind: MazeDestinationKind.kaaba,
      usesLightMarker: false,
    );
    _p1 = GameController(maze: _maze, level: level);
    _p2 = GameController(maze: _maze, level: level);
    _raceOverHandled = false;
    _raceId++;
  }

  void _onPlayerWon(int player) {
    if (_raceOverHandled) return;
    _raceOverHandled = true;
    _tickTimer?.cancel();
    MazeAudioService.instance.playWin();
    HapticFeedback.heavyImpact();
    _showWinnerDialog(player);
  }

  Future<void> _showWinnerDialog(int player) async {
    final t = AppLocalizations.of(context)!;
    final winnerName = player == 1 ? t.mazePlayerOneLabel : t.mazePlayerTwoLabel;
    final action = await showDialog<_RaceEndAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazeRaceWinnerTitle(winnerName)),
        actions: [
          TextButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              Navigator.of(context).pop(_RaceEndAction.exit);
            },
            child: Text(t.mazeLibraryCloseButton),
          ),
          FilledButton(
            onPressed: () {
              MazeAudioService.instance.playButtonTap();
              Navigator.of(context).pop(_RaceEndAction.raceAgain);
            },
            child: Text(t.mazeRaceAgainButton),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == _RaceEndAction.raceAgain) {
      setState(_startRace);
      _startTicking();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onPause() async {
    MazeAudioService.instance.playButtonTap();
    setState(() => _paused = true);
    _p1.pause();
    _p2.pause();
    final t = AppLocalizations.of(context)!;
    var endRace = false;
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
              endRace = true;
              Navigator.of(context).pop();
            },
            child: Text(t.mazeQuitButton),
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
    if (endRace) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _paused = false);
    _p1.resume();
    _p2.resume();
  }

  Widget _playerColumn({
    required int playerIndex,
    required String label,
    required GameController controller,
    required VoidCallback onWon,
    required ValueChanged<void Function(MazeDirection)> onMoveRequesterReady,
    required void Function(MazeDirection)? Function() getMover,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: MazeBoardWidget(
                key: ValueKey((_raceId, playerIndex)),
                controller: controller,
                solver: _solver,
                onWon: onWon,
                onMoveRequesterReady: onMoveRequesterReady,
                characterFillColor: _skin.fillColor,
                characterTrailColor: _skin.trailColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MazeDirectionPad(
              key: ValueKey('player${playerIndex}Pad'),
              onDirection: (d) => getMover()?.call(d),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: MazeColors.background,
          ),
        ),
        child: SafeArea(
          child: MazeClampedTextScale(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Transform.flip(
                          flipX: Directionality.of(context) == TextDirection.rtl,
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        onPressed: () {
                          MazeAudioService.instance.playButtonTap();
                          Navigator.of(context).pop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          t.mazeTwoPlayerTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white),
                        onPressed: _onPause,
                      ),
                    ],
                  ),
                ),
                _playerColumn(
                  playerIndex: 1,
                  label: t.mazePlayerOneLabel,
                  controller: _p1,
                  onWon: () => _onPlayerWon(1),
                  onMoveRequesterReady: (fn) => _p1Mover = fn,
                  getMover: () => _p1Mover,
                ),
                const Divider(color: MazeColors.boardBorder, height: 1),
                _playerColumn(
                  playerIndex: 2,
                  label: t.mazePlayerTwoLabel,
                  controller: _p2,
                  onWon: () => _onPlayerWon(2),
                  onMoveRequesterReady: (fn) => _p2Mover = fn,
                  getMover: () => _p2Mover,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _RaceEndAction { exit, raceAgain }
