import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The auth screen's calm, static brand mark — a flat gold-ringed teal medal
/// with a gentle "breathing" scale while busy and a one-off expanding ring
/// on success. Replaces the previous rotating glowing portal orb: no blur,
/// no radial-gradient glow, no spin — just a soft ordinary drop shadow.
class BrandMark extends StatefulWidget {
  const BrandMark({
    super.key,
    required this.size,
    this.busy = false,
    this.burstSignal = 0,
  });

  final double size;
  final bool busy;
  final int burstSignal;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _burst;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didUpdateWidget(covariant BrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.burstSignal != widget.burstSignal) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _burst]),
        builder: (context, _) {
          final breathe = widget.busy && !reduceMotion ? _pulse.value : 0.0;
          final scale = 1.0 + 0.03 * breathe;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (!reduceMotion && _burst.value > 0 && _burst.value < 1)
                Opacity(
                  opacity: 1 - _burst.value,
                  child: Container(
                    width: widget.size * (1.0 + 0.5 * _burst.value),
                    height: widget.size * (1.0 + 0.5 * _burst.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPalette.mutedGold, width: 1.6),
                    ),
                  ),
                ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.deepTeal,
                    border: Border.all(color: AppPalette.mutedGold, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.shadowInk,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppPalette.mutedGold,
                    size: widget.size * 0.34,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
