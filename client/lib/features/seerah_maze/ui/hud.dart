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
    this.ghostDeltaSeconds,
    this.bankRemaining,
    this.hintsLocked = false,
    this.reverseControlsActive = false,
  });

  final String levelName;
  final Duration elapsed;
  final int starsCollected;
  final int hintsRemaining;
  final VoidCallback onBack;
  final VoidCallback onHint;
  final VoidCallback onPause;
  final Axis axis;

  /// C1 — seconds ahead (negative) or behind (positive) the ghost's
  /// recorded run at the player's current cell. Null hides the pill
  /// entirely — no ghost racing, or the ghost never visited this cell.
  final double? ghostDeltaSeconds;

  /// A3 — keys picked up on this level, shown as an inventory. Empty on
  /// levels without doors, where the inventory isn't rendered at all.
  final Set<MazeKeyKind> heldKeys;

  /// C3 — Endless mode's shared time bank, counting down. Null hides the
  /// pill entirely (every non-Endless screen).
  final Duration? bankRemaining;

  /// C4 — true while the No-Hints Challenge is active: the hint button
  /// shows as locked (dimmed, outline icon, no remaining-uses badge)
  /// rather than simply being hidden, so it still reads as "there on
  /// purpose, just switched off" rather than a missing feature.
  final bool hintsLocked;

  /// C5 — shown as a quiet reminder pill whenever reverse controls are on,
  /// since nothing else on screen otherwise signals that every keypress
  /// now lands opposite to what was pressed.
  final bool reverseControlsActive;

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

  /// C1 — "-1.2s" (ahead of the ghost) or "+0.8s" (behind), hidden
  /// entirely when there's nothing to compare (see [ghostDeltaSeconds]).
  Widget? _ghostDeltaPill(AppLocalizations t) {
    final delta = ghostDeltaSeconds;
    if (delta == null) return null;
    final seconds = delta.abs().toStringAsFixed(1);
    final text = delta <= 0 ? t.mazeGhostDeltaAhead(seconds) : t.mazeGhostDeltaBehind(seconds);
    return Semantics(
      label: t.mazeGhostHudSemantics(text),
      child: _Pill(
        icon: Icons.timer_outlined,
        iconColor: delta <= 0 ? MazeColors.star : Colors.white,
        label: text,
      ),
    );
  }

  /// C3 — the Endless time bank, red-tinted once it's running low so the
  /// warning reads at a glance rather than only from the number itself.
  Widget? _bankPill(AppLocalizations t) {
    final bank = bankRemaining;
    if (bank == null) return null;
    final seconds = bank.inSeconds.clamp(0, 999);
    final low = bank <= const Duration(seconds: 10);
    return Semantics(
      label: t.mazeEndlessBankSemantics(seconds),
      child: _Pill(
        icon: Icons.hourglass_bottom_rounded,
        iconColor: low ? MazeColors.stormWarning : Colors.white,
        label: '${seconds}s',
      ),
    );
  }

  /// C5 — a plain reminder, not a stat: no value to read, just "this is
  /// on right now".
  Widget? _reverseBadge(AppLocalizations t) {
    if (!reverseControlsActive) return null;
    return Semantics(
      label: t.mazeReverseActiveSemantics,
      child: _Pill(icon: Icons.swap_horiz_rounded, label: t.mazeReverseActiveLabel),
    );
  }

  Widget _hintButton(AppLocalizations t) => Semantics(
        button: true,
        label: hintsLocked ? t.mazeHintLockedSemantics : t.mazeHudHintSemantics(hintsRemaining),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                hintsLocked ? Icons.lightbulb_outline_rounded : Icons.lightbulb_rounded,
                color: hintsLocked ? Colors.white.withValues(alpha: 0.35) : Colors.white,
              ),
              onPressed: hintsLocked ? null : (hintsRemaining > 0 ? onHint : null),
            ),
            if (!hintsLocked)
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
    final rawGhostPill = _ghostDeltaPill(t);
    // The delta text's length varies with the run (and with locale), so
    // this shrinks it rather than overflowing the narrow vertical side
    // panel on a longer reading — costs nothing when it already fits.
    final ghostPill =
        rawGhostPill == null ? null : FittedBox(fit: BoxFit.scaleDown, child: rawGhostPill);
    final rawBankPill = _bankPill(t);
    final bankPill =
        rawBankPill == null ? null : FittedBox(fit: BoxFit.scaleDown, child: rawBankPill);
    final rawReversePill = _reverseBadge(t);
    final reversePill =
        rawReversePill == null ? null : FittedBox(fit: BoxFit.scaleDown, child: rawReversePill);
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
                  if (ghostPill != null) ...[
                    const SizedBox(height: 8),
                    ghostPill,
                  ],
                  if (bankPill != null) ...[
                    const SizedBox(height: 8),
                    bankPill,
                  ],
                  if (reversePill != null) ...[
                    const SizedBox(height: 8),
                    reversePill,
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
                  if (ghostPill != null) ...[ghostPill, const SizedBox(width: 6)],
                  if (bankPill != null) ...[bankPill, const SizedBox(width: 6)],
                  if (reversePill != null) ...[reversePill, const SizedBox(width: 6)],
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
