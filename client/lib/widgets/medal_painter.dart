import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A flat, hand-drawn-style medal — the app's one custom trophy graphic,
/// used everywhere a stock `Icons.emoji_events_rounded` used to stand in:
/// the results screen, the session-complete card, and the leaderboard
/// podium badge. A gold disc with a teal rim, a star notch, and a short
/// two-tail ribbon underneath.
class MedalIcon extends StatelessWidget {
  const MedalIcon({super.key, this.size = 56, this.color, this.ribbonColor});

  final double size;
  final Color? color;
  final Color? ribbonColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _MedalPainter(
          diskColor: color ?? AppPalette.mutedGold,
          ribbonColor: ribbonColor ?? AppPalette.deepTeal,
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({required this.diskColor, required this.ribbonColor});

  final Color diskColor;
  final Color ribbonColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final diskRadius = w * 0.42;
    final diskCenter = Offset(w / 2, diskRadius + w * 0.06);

    // Ribbon tails, drawn first so they sit behind the disk.
    final ribbonPaint = Paint()..color = ribbonColor;
    final leftTail = Path()
      ..moveTo(diskCenter.dx - diskRadius * 0.45, diskCenter.dy)
      ..lineTo(diskCenter.dx - diskRadius * 0.75, size.height)
      ..lineTo(diskCenter.dx - diskRadius * 0.15, size.height * 0.86)
      ..close();
    final rightTail = Path()
      ..moveTo(diskCenter.dx + diskRadius * 0.45, diskCenter.dy)
      ..lineTo(diskCenter.dx + diskRadius * 0.75, size.height)
      ..lineTo(diskCenter.dx + diskRadius * 0.15, size.height * 0.86)
      ..close();
    canvas.drawPath(leftTail, ribbonPaint);
    canvas.drawPath(rightTail, ribbonPaint);

    // Outer disk (teal rim) + inner disk (gold face).
    canvas.drawCircle(diskCenter, diskRadius, Paint()..color = ribbonColor);
    canvas.drawCircle(diskCenter, diskRadius * 0.84, Paint()..color = diskColor);

    // A simple 5-point star notch in the center, cut in the rim color so it
    // reads as an embossed mark rather than a flat sticker.
    final starPaint = Paint()..color = ribbonColor.withValues(alpha: 0.9);
    canvas.drawPath(_starPath(diskCenter, diskRadius * 0.4, diskRadius * 0.17), starPaint);
  }

  Path _starPath(Offset center, double outerRadius, double innerRadius) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) =>
      oldDelegate.diskColor != diskColor || oldDelegate.ribbonColor != ribbonColor;
}
