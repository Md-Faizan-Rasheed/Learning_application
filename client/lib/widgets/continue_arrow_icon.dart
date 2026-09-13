import 'package:flutter/material.dart';

/// A simple custom "continue on your path" mark — a forward arrow with a
/// short curved trail behind it — replacing the stock rocket icon on the
/// Home screen's "Continue Learning" button.
class ContinueArrowIcon extends StatelessWidget {
  const ContinueArrowIcon({super.key, this.size = 20, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ContinueArrowPainter(color: color)),
    );
  }
}

class _ContinueArrowPainter extends CustomPainter {
  const _ContinueArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trailPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;

    final trail = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.30, size.height * 0.90,
        size.width * 0.52, size.height * 0.62,
      );
    canvas.drawPath(trail, trailPaint);

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shaft = Path()
      ..moveTo(size.width * 0.30, size.height * 0.72)
      ..lineTo(size.width * 0.82, size.height * 0.24);
    canvas.drawPath(shaft, arrowPaint);

    final head = Path()
      ..moveTo(size.width * 0.46, size.height * 0.18)
      ..lineTo(size.width * 0.86, size.height * 0.20)
      ..lineTo(size.width * 0.80, size.height * 0.58);
    canvas.drawPath(head, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _ContinueArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
