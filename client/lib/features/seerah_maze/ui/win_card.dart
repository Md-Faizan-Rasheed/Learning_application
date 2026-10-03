import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_levels.dart';
import '../logic/game_controller.dart';
import '../models/maze_level.dart';
import 'responsive/maze_breakpoints.dart';

/// What the player chose from the win card.
enum MazeWinAction { nextLevel, replay, levelSelect }

/// Shows the win card once [GameController.isWon]. Not dismissible by
/// tapping outside or dragging down — the player must make an explicit
/// choice. "Next Level" is omitted when [isLastLevel] is true.
Future<MazeWinAction?> showMazeWinCard(
  BuildContext context, {
  required MazeLevel level,
  required GameController controller,
  required bool isLastLevel,
  bool noHintsClear = false,
  bool isNewBestTime = false,
}) {
  return showModalBottomSheet<MazeWinAction>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => _WinCardContent(
      level: level,
      controller: controller,
      isLastLevel: isLastLevel,
      noHintsClear: noHintsClear,
      isNewBestTime: isNewBestTime,
    ),
  );
}

class _WinCardContent extends StatefulWidget {
  const _WinCardContent({
    required this.level,
    required this.controller,
    required this.isLastLevel,
    required this.noHintsClear,
    required this.isNewBestTime,
  });

  final MazeLevel level;
  final GameController controller;
  final bool isLastLevel;

  /// C4 — true when this win happened with the No-Hints Challenge active
  /// (so with zero hints used).
  final bool noHintsClear;

  /// E2 — true when this finish beat (or set) the level's previously
  /// stored best time, highlighting the time stat rather than adding a
  /// separate toast — the moment is already on screen right here.
  final bool isNewBestTime;

  @override
  State<_WinCardContent> createState() => _WinCardContentState();
}

class _WinCardContentState extends State<_WinCardContent> with TickerProviderStateMixin {
  late final AnimationController _starsController;
  int _lastHapticStarIndex = -1;

  /// E1 — a genuinely perfect clear (all 3 stars) gets a burst, the same
  /// ConfettiController/ConfettiWidget shape and duration
  /// widgets/session_complete_card.dart already uses elsewhere in the
  /// app, so this doesn't introduce a second celebration language.
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onStarsTick);
    _starsController.forward();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.controller.rating == MazeRating.three) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _starsController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onStarsTick() {
    final earned = widget.controller.rating.index + 1;
    final shown = (_starsController.value * earned).floor();
    if (shown > _lastHapticStarIndex) {
      _lastHapticStarIndex = shown;
      if (shown > 0) HapticFeedback.mediumImpact();
    }
  }

  double _starScale(int starIndex) {
    final earned = widget.controller.rating.index + 1;
    if (starIndex >= earned) return 0;
    final segment = 1 / earned;
    final progress = ((_starsController.value - starIndex * segment) / segment).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(progress);
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _resolve(MazeWinAction action) {
    MazeAudioService.instance.playButtonTap();
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final levelText = mazeLevelTextFor(t, widget.level.id);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _buildCard(context, colors, t, levelText),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          gravity: 0.3,
          shouldLoop: false,
          colors: const [
            MazeColors.characterFill,
            MazeColors.wall,
            MazeColors.boardPanel,
          ],
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations t,
    MazeLevelText levelText,
  ) {
    return SafeArea(
      child: MazeResponsiveSheet(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: const BoxDecoration(
            color: MazeColors.boardPanel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.noHintsClear) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MazeColors.star.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: MazeColors.star),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.military_tech_rounded, color: MazeColors.star, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          t.mazeNoHintsChallengeClearedBadge,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700, color: MazeColors.star),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                levelText.winLine,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _starsController,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Transform.scale(
                          scale: _starScale(i),
                          child: const Icon(Icons.star_rounded, color: MazeColors.star, size: 48),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBadge(
                    icon: Icons.timer_rounded,
                    label: widget.isNewBestTime ? t.mazeNewBestTimeBadge : t.mazeTimeStat,
                    value: _formatElapsed(widget.controller.elapsed),
                    highlight: widget.isNewBestTime,
                  ),
                  _StatBadge(
                    icon: Icons.lightbulb_rounded,
                    label: t.mazeHintsUsedStat,
                    value: '${widget.controller.hintsUsed}',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (!widget.isLastLevel)
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _resolve(MazeWinAction.nextLevel),
                    icon: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: const Icon(Icons.arrow_forward_rounded),
                    ),
                    label: Text(t.mazeNextLevelButton,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _resolve(MazeWinAction.replay),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(t.mazeReplayButton),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: () => _resolve(MazeWinAction.levelSelect),
                  icon: const Icon(Icons.map_rounded),
                  label: Text(t.mazeLevelSelectButton,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// E2 — a new best time swaps the usual muted styling for gold, same
  /// token the stars/achievements already use for "this one's special".
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: highlight ? MazeColors.star : colors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: highlight ? MazeColors.star : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlight ? FontWeight.w700 : null,
            color: highlight ? MazeColors.star : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
