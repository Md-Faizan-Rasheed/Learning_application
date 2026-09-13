import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's shared "physical card" surface: parchment-toned fill, a soft
/// drop shadow (not a glow), a hairline border, and a faint paper-grain
/// texture — the tactile alternative to a flat Material rectangle or a
/// frosted-glass panel. Wrap any container that should read as a distinct
/// piece of card stock sitting on the page.
class CardStock extends StatelessWidget {
  const CardStock({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 12.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppPalette.borderTaupe),
    );

    return Container(
      decoration: BoxDecoration(
        color: color ?? AppPalette.cardStock,
        borderRadius: BorderRadius.circular(radius),
        border: const Border.fromBorderSide(BorderSide(color: AppPalette.borderTaupe)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadowInk,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: const PaperGrainPainter(),
          child: Material(
            type: MaterialType.transparency,
            shape: onTap != null ? shape : null,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A `BoxDecoration` builder for spots that can't wrap a full [CardStock]
/// widget (e.g. inside an existing `AnimatedContainer`) but still want the
/// same card-stock fill/border/shadow treatment.
BoxDecoration cardStockDecoration({
  double borderRadius = 12,
  Color? color,
  Color? borderColor,
  List<BoxShadow>? boxShadow,
}) {
  return BoxDecoration(
    color: color ?? AppPalette.cardStock,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor ?? AppPalette.borderTaupe),
    boxShadow: boxShadow ??
        [
          BoxShadow(
            color: AppPalette.shadowInk,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
  );
}

/// A fixed, seeded scatter of tiny dots at 1-2% opacity — the "paper grain"
/// texture. Painted once; `shouldRepaint` only fires on an actual size
/// change, so this never costs a per-frame recompute. Public so other
/// card-stock-styled widgets that can't wrap the full [CardStock] widget
/// (e.g. [OptionTile]) can still paint the same grain.
class PaperGrainPainter extends CustomPainter {
  const PaperGrainPainter();

  static const _seed = 42;
  static const _dotsPerArea = 0.35; // dots per square dp, roughly

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(_seed);
    final count = (size.width * size.height * _dotsPerArea / 1000).clamp(40, 400).toInt();
    final paint = Paint()..color = AppPalette.ink.withValues(alpha: 0.05);
    for (var i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.4 + rng.nextDouble() * 0.7;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) => false;
}
