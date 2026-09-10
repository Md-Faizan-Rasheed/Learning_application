import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared across every "answer a multiple-choice question" screen (practice,
/// teacher-assigned quizzes). Neutral until answered; the server's verdict
/// then colors it green/red — the client never decides correctness itself.
enum OptionState { neutral, correct, wrong }

/// Bump fraction (0 -> 1 -> 0) used to drive the correct-answer "pop" scale
/// and its glow — kept separate from the actual scale value so a caller's
/// [OptionTile.comboBoost] can amplify the same curve shape.
final _bumpTween = TweenSequence<double>([
  TweenSequenceItem(
      tween:
          Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35),
  TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 65),
]);

final _shakeTween = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
  TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
  TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
  TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 1),
  TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
]);

class OptionTile extends StatefulWidget {
  const OptionTile({
    super.key,
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
    this.comboBoost = 1.0,
    this.index = 0,
  });

  final String text;
  final bool selected;
  final OptionState state;
  final VoidCallback? onTap;

  /// Scales the correct-answer pop and glow — pass a value above 1.0 to make
  /// the reveal feel bigger as a streak builds (see PracticeScreen's combo
  /// tracking). 1.0 is the normal, unboosted reveal.
  final double comboBoost;

  /// This tile's position in its option list — offsets the idle "floating on
  /// water" bob's phase so a row of tiles doesn't bob in lockstep. Purely
  /// cosmetic; safe to leave at the default when there's only one tile.
  final int index;

  @override
  State<OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<OptionTile> with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    // A tile can already be graded on first build (e.g. rebuilt from saved
    // state) — only animate the reveal, not every subsequent rebuild.
    if (widget.state != OptionState.neutral) _reveal.value = 1;

    // Idle "floating on water" drift — only meaningful before an answer is
    // locked in; the reveal animation takes over once graded.
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant OptionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == OptionState.neutral &&
        widget.state != OptionState.neutral) {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _idle]),
      builder: (context, _) {
        Color? bg;
        late final Color border;
        switch (widget.state) {
          case OptionState.correct:
            bg = Colors.green.withValues(alpha: 0.15);
            border = Colors.green;
            break;
          case OptionState.wrong:
            bg = Colors.red.withValues(alpha: 0.15);
            border = Colors.red;
            break;
          case OptionState.neutral:
            bg = widget.selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : null;
            border = widget.selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey;
        }

        final bump = widget.state == OptionState.correct
            ? _bumpTween.evaluate(_reveal)
            : 0.0;
        final scale = 1.0 + (bump * 0.08 * widget.comboBoost);
        final dx = widget.state == OptionState.wrong
            ? _shakeTween.evaluate(_reveal)
            : 0.0;

        final glow = widget.state == OptionState.correct
            ? bump * widget.comboBoost
            : (widget.state == OptionState.wrong ? (1 - _reveal.value) : 0.0);
        final glowColor =
            widget.state == OptionState.wrong ? Colors.red : Colors.green;

        // Gentle bob while unanswered — a settled, non-neutral tile (already
        // graded, or shown read-only in a match report) stays put. Vertical
        // and horizontal drift run at different speeds/phases (each seeded
        // by this tile's index) so every option floats on its own, rather
        // than all rising and falling — or rocking — in lockstep. Both waves
        // are zero-centered, so the tile drifts evenly either side of rest
        // instead of leaning toward one edge.
        final floating = !reduceMotion && widget.state == OptionState.neutral;
        final bobPhase = widget.index * 1.7;
        final verticalWave =
            floating ? math.sin((_idle.value * 2 * math.pi) + bobPhase) : 0.0;
        final horizontalWave = floating
            ? math.sin((_idle.value * 2 * math.pi * 0.63) + bobPhase + 2.1)
            : 0.0;
        final floatDy = verticalWave * 4.0;
        final floatDx = horizontalWave * 2.5;

        return Transform.translate(
          offset: Offset(dx + floatDx, floatDy),
          child: Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border, width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (widget.state != OptionState.neutral)
                    BoxShadow(
                      color: border.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  if (glow > 0)
                    BoxShadow(
                      color: glowColor.withValues(
                          alpha: (0.45 * glow).clamp(0.0, 0.45)),
                      blurRadius: 8 + 22 * glow,
                      spreadRadius: 6 * glow,
                    ),
                ],
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.text,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (widget.state == OptionState.correct)
                        Transform.scale(
                          scale: Curves.elasticOut.transform(_reveal.value),
                          child: const Icon(Icons.check_circle_rounded,
                              color: Colors.green),
                        )
                      else if (widget.state == OptionState.wrong)
                        Transform.scale(
                          scale: Curves.elasticOut.transform(_reveal.value),
                          child: const Icon(Icons.cancel_rounded,
                              color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
