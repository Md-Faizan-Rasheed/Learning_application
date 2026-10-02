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
    ),
  );
}

class _WinCardContent extends StatefulWidget {
  const _WinCardContent({
    required this.level,
    required this.controller,
    required this.isLastLevel,
  });

  final MazeLevel level;
  final GameController controller;
  final bool isLastLevel;

  @override
  State<_WinCardContent> createState() => _WinCardContentState();
}

class _WinCardContentState extends State<_WinCardContent> with TickerProviderStateMixin {
  late final AnimationController _starsController;
  int _lastHapticStarIndex = -1;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onStarsTick);
    _starsController.forward();
  }

  @override
  void dispose() {
    _starsController.dispose();
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
                    label: t.mazeTimeStat,
                    value: _formatElapsed(widget.controller.elapsed),
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
  const _StatBadge({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
      ],
    );
  }
}
