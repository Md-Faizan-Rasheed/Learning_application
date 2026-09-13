import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One player's seat, shared by the lobby's card-table layout and the
/// in-question opponent-presence row so both read as the same design.
///
/// Filled seats show a teal-ringed initial-letter badge (or a bot glyph).
/// Empty seats show a dashed outline with a slow pulsing teal glow, so an
/// open seat reads as "waiting," not just blank.
class SeatMarker extends StatefulWidget {
  const SeatMarker({
    super.key,
    this.name,
    this.isBot = false,
    this.answered = false,
    this.highlighted = false,
    this.size = 48,
  });

  /// Null means this seat is empty (nobody has joined it yet).
  final String? name;
  final bool isBot;

  /// Marks this seat as "has answered the current question" — a filled
  /// teal check overlay instead of the initial letter.
  final bool answered;

  /// This is the local player's own seat — gets a gold ring instead of teal.
  final bool highlighted;
  final double size;

  @override
  State<SeatMarker> createState() => _SeatMarkerState();
}

class _SeatMarkerState extends State<SeatMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.name == null) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SeatMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final empty = widget.name == null;
    if (empty && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!empty && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ringColor = widget.highlighted ? AppPalette.mutedGold : AppPalette.deepTeal;

    if (widget.name == null) {
      // Empty seat — dashed outline, slow pulsing teal glow while waiting.
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = reduceMotion ? 0.5 : Curves.easeInOut.transform(_pulse.value);
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.cardStock,
              boxShadow: [
                BoxShadow(
                  color: AppPalette.deepTeal.withValues(alpha: 0.10 + 0.18 * t),
                  blurRadius: 6 + 10 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _DashedRingPainter(color: AppPalette.borderTaupe),
              child: Center(
                child: Icon(Icons.hourglass_empty_rounded,
                    color: AppPalette.inkMuted, size: widget.size * 0.34),
              ),
            ),
          );
        },
      );
    }

    final initial = widget.name!.trim().isNotEmpty
        ? widget.name!.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.cardStock,
        border: Border.all(color: ringColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadowInk,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: widget.answered
            ? Icon(Icons.check_rounded, color: AppPalette.deepTeal, size: widget.size * 0.5)
            : widget.isBot
                ? Icon(Icons.smart_toy_rounded, color: AppPalette.deepTeal, size: widget.size * 0.46)
                : Text(
                    initial,
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: widget.size * 0.38,
                    ),
                  ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 14;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (2 * 3.14159265 / dashCount) * i;
      final sweep = (2 * 3.14159265 / dashCount) * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
