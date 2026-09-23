import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/name_drag_payload.dart';
import '../utils/word_bank_entry.dart';
import 'card_stock.dart' show PaperGrainPainter;

/// One name floating on the "Names of Allah" pool's water surface — the
/// visual sibling of the old (now-removed) `FloatingPad`, adapted to drag
/// a [NameDragPayload] instead of a raw [WordEntry] so it plays correctly
/// with meaning boxes that accept any drop unconditionally: there is no
/// "wrong drop" flash here anymore, since correctness is never decided
/// until Submit.
///
/// Motion is phase-based, not a Curve applied to a ping-pong tween: one
/// continuously-looping controller (`..repeat()`, never reversed) drives a
/// phase value, and vertical/horizontal offsets are computed as sine
/// functions of that phase with per-card-random amplitude, duration, start
/// offset, and a horizontal/vertical frequency ratio — that last part is
/// what keeps two cards from ever *looking* synced even if their phase
/// happens to briefly line up.
class FloatingNameCard extends StatefulWidget {
  const FloatingNameCard({
    super.key,
    required this.entry,
    required this.size,
    required this.floatRange,
    required this.reduceMotion,
    required this.reflowNonce,
  });

  final WordEntry entry;

  /// Side length of the card's tap target — already clamped by the caller
  /// to the platform's minimum and scaled from the water container's own
  /// measured size, never a fixed constant.
  final double size;

  /// Max vertical amplitude in px, derived by the caller from the water
  /// container's actual rendered height.
  final double floatRange;

  final bool reduceMotion;

  /// Bumped by the caller whenever the pool's card count changes (one
  /// dragged out, or one dragged back in) — nudges this card's drift
  /// slightly rather than a full re-seed, so motion stays continuous but
  /// the remaining cards don't all look identically tuned afterward.
  final int reflowNonce;

  @override
  State<FloatingNameCard> createState() => _FloatingNameCardState();
}

class _FloatingNameCardState extends State<FloatingNameCard> with TickerProviderStateMixin {
  late final math.Random _rng;
  late AnimationController _floatController;
  late AnimationController _wiggleController;
  Timer? _perturbTimer;
  bool _dragging = false;

  late double _amplitude;
  late double _swayAmplitude;
  late double _freqRatio;
  late double _phaseOffset;

  // Fixed for this card's whole lifetime — a small static tilt so cards
  // don't look machine-stamped, and a depth factor that scales this
  // card's shadow so some read as slightly nearer and some farther.
  late double _tilt;
  late double _depth;

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    _rollMotionParams();
    _tilt = (_rng.nextDouble() * 2 - 1) * (4 * math.pi / 180); // -4..4 degrees
    _depth = _rng.nextDouble();

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
  void didUpdateWidget(FloatingNameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reflowNonce != oldWidget.reflowNonce) {
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

  /// Same card-stock look (cardStock fill, borderTaupe hairline, paper
  /// grain) as [CardStock] elsewhere in the app, with its own shadow
  /// varied by [_depth] for a mild sense of depth across the floating layer.
  Widget _buildChip() {
    final radius = BorderRadius.circular(12);
    return Container(
      width: widget.size,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.cardStock,
        borderRadius: radius,
        border: Border.all(color: AppPalette.borderTaupe),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadowInk.withValues(alpha: 0.10 + _depth * 0.14),
            blurRadius: 6 + _depth * 10,
            offset: Offset(0, 3 + _depth * 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: const PaperGrainPainter(),
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
                    fontSize: 15,
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
                style: TextStyle(fontSize: 10, color: AppPalette.inkMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draggable = Draggable<NameDragPayload>(
      data: NameDragPayload(entry: widget.entry, sourceBox: null),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.08, child: _buildChip()),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _buildChip()),
      onDragStarted: () {
        HapticFeedback.selectionClick();
        _pauseMotion();
      },
      onDragEnd: (_) => _resumeMotion(),
      child: _buildChip(),
    );

    if (widget.reduceMotion) {
      // Tilt is a static layout/style choice (scattered, not machine-
      // stamped), independent of the reduced-motion drift/wiggle.
      return Transform.rotate(angle: _tilt, child: draggable);
    }

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
          child: Transform.rotate(angle: _tilt + wiggleAngle, child: child),
        );
      },
    );
  }
}
