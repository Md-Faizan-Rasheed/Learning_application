import 'package:flutter/material.dart';

/// A simple hand-drawn-style checkmark stroke — the custom replacement for
/// `Icons.check_circle_rounded` on a correct answer.
class CheckmarkPainter extends CustomPainter {
  const CheckmarkPainter({required this.color, this.strokeWidth = 3});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.80)
      ..lineTo(size.width * 0.86, size.height * 0.24);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// A simple hand-drawn-style cross stroke — the custom replacement for
/// `Icons.cancel_rounded` on a wrong answer.
class CrossPainter extends CustomPainter {
  const CrossPainter({required this.color, this.strokeWidth = 3});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.22),
      Offset(size.width * 0.78, size.height * 0.78),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.78),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CrossPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
