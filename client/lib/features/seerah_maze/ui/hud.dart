import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../constants/maze_door_styles.dart';
import '../models/maze_door.dart';
import 'responsive/maze_breakpoints.dart';

/// HUD for the game screen: back, level name + timer, star count, hint
/// button (with remaining-uses badge), and pause. Renders as a horizontal
/// top bar in portrait/compact layouts, or (when [axis] is
/// [Axis.vertical]) as a narrow side panel for landscape/expanded screens
/// — same elements, same callbacks, just re-flowed, so every call site
/// keeps behaving identically regardless of which arrangement is active.
class MazeHud extends StatelessWidget {
  const MazeHud({
    super.key,
    required this.levelName,
    required this.elapsed,
    required this.starsCollected,
    required this.onBack,
    required this.onHint,
    required this.onPause,
    this.hintsRemaining = MazeConstants.maxHintsPerLevel,
    this.axis = Axis.horizontal,
    this.heldKeys = const {},
  });

  final String levelName;
  final Duration elapsed;
  final int starsCollected;
  final int hintsRemaining;
  final VoidCallback onBack;
  final VoidCallback onHint;
  final VoidCallback onPause;
  final Axis axis;

  /// A3 — keys picked up on this level, shown as an inventory. Empty on
  /// levels without doors, where the inventory isn't rendered at all.
  final Set<MazeKeyKind> heldKeys;

  String _formatElapsed() {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _backButton(AppLocalizations t, BuildContext context) => Semantics(
        button: true,
        label: t.mazeHudBackSemantics,
        child: IconButton(
          icon: Transform.flip(
            flipX: Directionality.of(context) == TextDirection.rtl,
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          onPressed: onBack,
        ),
      );

  Widget _levelAndTimer(AppLocalizations t, {int titleMaxLines = 1}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            levelName,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Semantics(
            label: t.mazeHudElapsedSemantics(_formatElapsed()),
            child: Text(
              _formatElapsed(),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      );

  /// A3 — one badge per key in hand, each showing its kind's own icon
  /// (not just its color) so the match to a door is readable either way.
  Widget _keyInventory(AppLocalizations t) => Semantics(
        label: t.mazeHudKeysSemantics(heldKeys.length),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in MazeKeyKind.values)
              if (heldKeys.contains(kind))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    mazeDoorStyleFor(kind).icon,
                    size: 16,
                    color: mazeDoorStyleFor(kind).color,
                  ),
                ),
          ],
        ),
      );

  Widget _starsPill(AppLocalizations t) => Semantics(
        label: t.mazeHudStarsSemantics(starsCollected, MazeConstants.collectibleStarCount),
        child: _Pill(
          icon: Icons.star_rounded,
          iconColor: MazeColors.star,
          label: '$starsCollected/${MazeConstants.collectibleStarCount}',
        ),
      );

  Widget _hintButton(AppLocalizations t) => Semantics(
        button: true,
        label: t.mazeHudHintSemantics(hintsRemaining),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.lightbulb_rounded, color: Colors.white),
              onPressed: hintsRemaining > 0 ? onHint : null,
            ),
            Positioned(right: 4, top: 4, child: _Pill(label: '$hintsRemaining', dense: true)),
          ],
        ),
      );

  Widget _pauseButton(AppLocalizations t) => Semantics(
        button: true,
        label: t.mazeHudPauseSemantics,
        child: IconButton(
          icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white),
          onPressed: onPause,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final content = axis == Axis.vertical
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                children: [
                  _backButton(t, context),
                  const SizedBox(height: 10),
                  _levelAndTimer(t, titleMaxLines: 3),
                  const SizedBox(height: 12),
                  _starsPill(t),
                  if (heldKeys.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _keyInventory(t),
                  ],
                  const Spacer(),
                  _hintButton(t),
                  const SizedBox(height: 8),
                  _pauseButton(t),
                ],
              ),
            ),
          )
        : SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _backButton(t, context),
                  Expanded(child: _levelAndTimer(t)),
                  if (heldKeys.isNotEmpty) _keyInventory(t),
                  _starsPill(t),
                  const SizedBox(width: 6),
                  _hintButton(t),
                  _pauseButton(t),
                ],
              ),
            ),
          );
    return MazeClampedTextScale(child: content);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({this.icon, this.iconColor, required this.label, this.dense = false});

  final IconData? icon;
  final Color? iconColor;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 8, vertical: dense ? 1 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: iconColor, size: 14),
          if (icon != null) const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: dense ? 10 : 12),
          ),
        ],
      ),
    );
  }
}
