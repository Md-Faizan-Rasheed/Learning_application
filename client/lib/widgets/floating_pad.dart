import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/word_bank_entry.dart';
import 'card_stock.dart';

/// One name floating on the water surface — a card-stock chip (matching
/// every other piece of content in this app, not a lily-pad shape) with its
/// own independently-randomized drift, wrapped in a stock [Draggable].
///
/// Motion is phase-based, not a Curve applied to a ping-pong tween: one
/// continuously-looping controller (`..repeat()`, never reversed) drives a
/// phase value, and vertical/horizontal offsets are computed as sine
/// functions of that phase with per-pad-random amplitude, duration, start
/// offset, and a horizontal/vertical frequency ratio. That last part is
/// what keeps two pads from ever *looking* synced even if their phase
/// happens to briefly line up — their whole drift pattern differs, not
/// just their timing.
class FloatingPad extends StatefulWidget {
  const FloatingPad({
    super.key,
    required this.entry,
    required this.size,
    required this.floatRange,
    required this.reduceMotion,
    required this.reflowNonce,
    required this.onDropResult,
  });

  final WordEntry entry;

  /// Side length of the pad's tap target — already clamped by the caller to
  /// the platform's minimum (48px) and scaled from the water container's
  /// own measured size, never a fixed constant.
  final double size;

  /// Max vertical amplitude in px, derived by the caller from the water
  /// container's actual rendered height — not a fixed pixel value, so a
  /// small phone and a tablet get proportionally different drift.
  final double floatRange;

  final bool reduceMotion;

  /// Bumped by the caller whenever the active batch's pad count changes
  /// (a reflow) — triggers a small, continuous-motion-preserving jitter to
  /// this pad's amplitude/sway/frequency rather than a full re-seed, so
  /// remaining pads don't all look identically tuned after one is removed.
  final int reflowNonce;

  /// Called after a drag ends: true if accepted by a DragTarget, false if
  /// dropped on nothing or rejected. The screen owns match-state and
  /// sound/haptics; this widget only owns its own transient wrong-flash.
  final ValueChanged<bool> onDropResult;

  @override
  State<FloatingPad> createState() => _FloatingPadState();
}

class _FloatingPadState extends State<FloatingPad> with TickerProviderStateMixin {
  late final math.Random _rng;
  late AnimationController _floatController;
  late AnimationController _wiggleController;
  Timer? _perturbTimer;
  Timer? _wrongFlashTimer;
  bool _wrongFlash = false;
  bool _dragging = false;

  late double _amplitude;
  late double _swayAmplitude;
  late double _freqRatio;
  late double _phaseOffset;

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    _rollMotionParams();

    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2600 + _rng.nextInt(1600)), // 2.6-4.2s
    );
    _wiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    if (!widget.reduceMotion) {
      _floatController.repeat();
      _schedulePerturbation();
    }
  }

  void _rollMotionParams() {
    _amplitude = (6 + _rng.nextDouble() * 8).clamp(0, widget.floatRange);
    _swayAmplitude = 3 + _rng.nextDouble() * 3;
    _freqRatio = 1.15 + _rng.nextDouble() * 0.30;
    _phaseOffset = _rng.nextDouble() * 2 * math.pi;
  }

  void _schedulePerturbation() {
    _perturbTimer?.cancel();
    final delay = Duration(seconds: 6 + _rng.nextInt(9)); // 6-14s
    _perturbTimer = Timer(delay, () {
      if (!mounted || _dragging) return;
      _wiggleController.forward(from: 0).whenComplete(() {
        if (mounted && !_dragging) _schedulePerturbation();
      });
    });
  }

  @override
  void didUpdateWidget(FloatingPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reflowNonce != oldWidget.reflowNonce) {
      // A pad elsewhere in the batch was matched and removed — nudge this
      // pad's drift slightly rather than a full re-seed, so motion stays
      // continuous (no jump) but the remaining pads don't all look frozen
      // in whatever pattern they started with.
      setState(() {
        _amplitude = (_amplitude * (0.85 + _rng.nextDouble() * 0.3)).clamp(4, widget.floatRange);
        _swayAmplitude = (_swayAmplitude * (0.85 + _rng.nextDouble() * 0.3)).clamp(2, 8);
        _freqRatio = (_freqRatio * (0.9 + _rng.nextDouble() * 0.2)).clamp(1.05, 1.6);
      });
    }
  }

  @override
  void dispose() {
    _perturbTimer?.cancel();
    _wrongFlashTimer?.cancel();
    _floatController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  void _pauseMotion() {
    setState(() => _dragging = true);
    _floatController.stop();
    _perturbTimer?.cancel();
  }

  void _resumeMotion() {
    if (!mounted) return;
    setState(() => _dragging = false);
    if (!widget.reduceMotion) {
      // Resumes from the controller's existing .value — no reset, so the
      // drift picks back up exactly where it left off instead of jumping.
      _floatController.repeat();
      _schedulePerturbation();
    }
  }

  void _flashWrong() {
    _wrongFlashTimer?.cancel();
    setState(() => _wrongFlash = true);
    _wrongFlashTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _wrongFlash = false);
    });
  }

  Widget _buildChip() {
    return CardStock(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 12,
      child: SizedBox(
        width: widget.size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                widget.entry.arabicScript,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppPalette.ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.entry.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppPalette.inkMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: _wrongFlash ? Border.all(color: AppPalette.incorrectRed, width: 2) : null,
      ),
      child: _buildChip(),
    );

    final draggable = Draggable<WordEntry>(
      data: widget.entry,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.08, child: _buildChip()),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _buildChip()),
      onDragStarted: _pauseMotion,
      onDragEnd: (details) {
        _resumeMotion();
        if (!details.wasAccepted) {
          _flashWrong();
          HapticFeedback.mediumImpact();
        }
        widget.onDropResult(details.wasAccepted);
      },
      child: chip,
    );

    if (widget.reduceMotion) return draggable;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _wiggleController]),
      // The chip content is built once and passed as `child` — only the
      // Transform wrapper below rebuilds every frame.
      child: draggable,
      builder: (context, child) {
        final phase = _floatController.value * 2 * math.pi;
        final vertical = _amplitude * math.sin(phase + _phaseOffset);
        final horizontal =
            _swayAmplitude * math.sin(phase * _freqRatio + _phaseOffset + math.pi / 4);
        final wiggleAngle = math.sin(_wiggleController.value * math.pi) *
            (1.5 * math.pi / 180); // ±1.5°, one-shot

        return Transform.translate(
          offset: Offset(horizontal, vertical),
          child: Transform.rotate(angle: wiggleAngle, child: child),
        );
      },
    );
  }
}
