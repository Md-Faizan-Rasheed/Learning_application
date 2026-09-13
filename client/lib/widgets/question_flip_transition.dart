import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps a question card so a new question turns over like a physical card
/// instead of just cross-fading in. Pass a [flipKey] that changes exactly
/// when the underlying question changes (e.g. its id) — everything else
/// (countdown ticks, answer selection) can rebuild this widget without
/// re-triggering the flip.
class QuestionFlipTransition extends StatefulWidget {
  const QuestionFlipTransition({
    super.key,
    required this.flipKey,
    required this.child,
  });

  final Object flipKey;
  final Widget child;

  @override
  State<QuestionFlipTransition> createState() => _QuestionFlipTransitionState();
}

class _QuestionFlipTransitionState extends State<QuestionFlipTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _previousChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant QuestionFlipTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipKey != widget.flipKey) {
      _previousChild = oldWidget.child;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || _previousChild == null) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        if (t >= 1) return widget.child;

        final angle = t * math.pi;
        final showPrevious = t < 0.5;
        final displayChild = showPrevious ? _previousChild! : widget.child;
        final displayAngle = showPrevious ? angle : angle - math.pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(displayAngle),
          child: displayChild,
        );
      },
    );
  }
}
