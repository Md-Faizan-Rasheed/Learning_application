import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_mechanic_tooltip_icons.dart';
import '../models/maze_mechanics.dart';
import 'responsive/maze_breakpoints.dart';

String _textFor(AppLocalizations t, MazeMechanicTooltip tooltip) => switch (tooltip) {
      MazeMechanicTooltip.caravan => t.mazeTooltipCaravan,
      MazeMechanicTooltip.cave => t.mazeTooltipCave,
      MazeMechanicTooltip.doors => t.mazeTooltipDoors,
      MazeMechanicTooltip.sand => t.mazeTooltipSand,
      MazeMechanicTooltip.sandstorm => t.mazeTooltipSandstorm,
      MazeMechanicTooltip.teleport => t.mazeTooltipTeleport,
      MazeMechanicTooltip.shiftingWalls => t.mazeTooltipShiftingWalls,
      MazeMechanicTooltip.oneWay => t.mazeTooltipOneWay,
    };

/// A8 — a queue of one-time "here's how this works" introductions for
/// whichever mechanics a level introduces for the first time.
///
/// Shows one at a time, animates in, and advances to the next on tap (or
/// disappears if that was the last one). [queue] should already be
/// filtered down to mechanics the player hasn't seen before — this widget
/// only handles presenting that queue, not deciding what belongs in it
/// (MazeGameScreen does that against MazeProgress.seenMechanicTooltips).
class MazeMechanicTooltipBanner extends StatefulWidget {
  const MazeMechanicTooltipBanner({
    super.key,
    required this.queue,
    required this.onDismissedAll,
  });

  final List<MazeMechanicTooltip> queue;

  /// Called once every tooltip in the queue has been dismissed.
  final VoidCallback onDismissedAll;

  @override
  State<MazeMechanicTooltipBanner> createState() => _MazeMechanicTooltipBannerState();
}

class _MazeMechanicTooltipBannerState extends State<MazeMechanicTooltipBanner> {
  int _index = 0;

  void _advance() {
    if (_index + 1 >= widget.queue.length) {
      widget.onDismissedAll();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queue.isEmpty || _index >= widget.queue.length) {
      return const SizedBox.shrink();
    }
    final t = AppLocalizations.of(context)!;
    final tooltip = widget.queue[_index];

    return MazeClampedTextScale(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(tooltip),
          child: Semantics(
            liveRegion: true,
            button: true,
            label: _textFor(t, tooltip),
            // Without this, the child Text widget's own automatic
            // semantics merges with this explicit label (since they're
            // the same string, the merge doubles it up), so a test
            // searching for the plain label text finds nothing exact.
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _advance,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(mazeMechanicTooltipIconFor(tooltip), color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _textFor(t, tooltip),
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
