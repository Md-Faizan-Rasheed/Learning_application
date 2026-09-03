import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Convenience wrapper for the common case: put [AmbientBackdrop] full-bleed
/// behind a screen's existing body content in one call, instead of hand
/// -writing a `Stack` at every call site.
class ScreenWithAmbientBackdrop extends StatelessWidget {
  const ScreenWithAmbientBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AmbientBackdrop()),
        child,
      ],
    );
  }
}

const _letterPool = [
  'ا',
  'ب',
  'ت',
  'ث',
  'ج',
  'ح',
  'خ',
  'د',
  'ر',
  'س',
  'ش',
  'ص',
  'ض',
  'ط',
  'ظ',
  'ع',
  'غ',
  'ف',
  'ق',
  'ك',
  'ل',
  'م',
  'ن',
  'ه',
  'و',
  'ي',
];

// Depth layers, back to front, per the spec: tiny distant particles, medium
// glowing drifting letters, then a few large very-faint foreground letters.
const _starCount = (mobile: 8, desktop: 16);
const _midCount = (mobile: 4, desktop: 7);
const _foreCount = (mobile: 2, desktop: 3);
const _narrowBreakpoint = 600.0;

class _Star {
  _Star(
      {required this.dx,
      required this.dy,
      required this.radius,
      required this.phase,
      required this.speed});
  final double dx, dy, radius, phase, speed;
}

class _Letter {
  _Letter({
    required this.painter,
    required this.dx,
    required this.dy,
    required this.phase,
    required this.speed,
    required this.driftDx,
    required this.driftDy,
    required this.rotation,
    required this.baseAlpha,
  });
  final TextPainter painter;
  final double dx, dy, phase, speed, driftDx, driftDy, rotation, baseAlpha;
}

/// A living Arabic-letter atmosphere shared by every screen: a back layer of
/// tiny twinkling particles, a mid layer of medium glowing drifting letters,
/// and a foreground layer of large, very-faint letters — reusing the same
/// AnimationController+CustomPaint+precomputed-TextPainter technique proven
/// in the auth screen's `AnimatedNightBackground`, generalized with the full
/// alphabet, three depth layers, and a reduced element count on narrow
/// screens. Reads colors from the shared [AppPalette] so it matches the app
/// theme everywhere. Respects `MediaQuery.disableAnimations`.
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({super.key});

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;
  late final List<_Letter> _mid;
  late final List<_Letter> _fore;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 34));
    final rng = math.Random(17);
    final letters = [..._letterPool]..shuffle(rng);
    var next = 0;
    String nextLetter() => letters[(next++) % letters.length];

    _stars = List.generate(
      _starCount.desktop,
      (_) => _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.3,
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.5 + rng.nextDouble() * 0.7,
      ),
    );

    _mid = List.generate(
        _midCount.desktop,
        (_) => _buildLetter(rng, nextLetter(),
            fontSize: 22 + rng.nextDouble() * 12, baseAlpha: 0.20));
    _fore = List.generate(
        _foreCount.desktop,
        (_) => _buildLetter(rng, nextLetter(),
            fontSize: 46 + rng.nextDouble() * 22, baseAlpha: 0.07));
  }

  _Letter _buildLetter(math.Random rng, String char,
      {required double fontSize, required double baseAlpha}) {
    final painter = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(
            fontSize: fontSize,
            color: AppPalette.textPrimary,
            fontWeight: FontWeight.w300),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    return _Letter(
      painter: painter,
      dx: 0.05 + rng.nextDouble() * 0.9,
      dy: 0.05 + rng.nextDouble() * 0.9,
      phase: rng.nextDouble() * math.pi * 2,
      speed: 0.4 + rng.nextDouble() * 0.5,
      driftDx: (rng.nextDouble() - 0.5) * 0.10,
      driftDy: (rng.nextDouble() - 0.5) * 0.14,
      rotation: (rng.nextDouble() - 0.5) * 0.35,
      baseAlpha: baseAlpha,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    final narrow = MediaQuery.of(context).size.width < _narrowBreakpoint;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _WorldPainter(
              t: reduceMotion ? 0 : _controller.value,
              animate: !reduceMotion,
              stars: _stars
                  .take(narrow ? _starCount.mobile : _starCount.desktop)
                  .toList(growable: false),
              mid: _mid
                  .take(narrow ? _midCount.mobile : _midCount.desktop)
                  .toList(growable: false),
              fore: _fore
                  .take(narrow ? _foreCount.mobile : _foreCount.desktop)
                  .toList(growable: false),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(
      {required this.t,
      required this.animate,
      required this.stars,
      required this.mid,
      required this.fore});

  final double t;
  final bool animate;
  final List<_Star> stars;
  final List<_Letter> mid;
  final List<_Letter> fore;

  void _paintLetter(Canvas canvas, Size size, _Letter l,
      {required double glowBoost}) {
    final bob = animate ? math.sin(t * 2 * math.pi * l.speed + l.phase) : 0.0;
    final origin = Offset(
      (l.dx + (animate ? bob * l.driftDx : 0)) * size.width,
      (l.dy + (animate ? bob * l.driftDy : 0)) * size.height,
    );
    final breathing = animate
        ? (0.5 + 0.5 * math.sin(t * 2 * math.pi * l.speed * 0.7 + l.phase))
        : 0.6;
    final alpha =
        (l.baseAlpha * (0.6 + 0.7 * breathing) * glowBoost).clamp(0.0, 1.0);
    final angle = animate
        ? l.rotation * math.sin(t * 2 * math.pi * l.speed * 0.5 + l.phase)
        : 0.0;

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final bounds = Rect.fromLTWH(0, 0, l.painter.width, l.painter.height);
    canvas.saveLayer(
        bounds, Paint()..color = Colors.white.withValues(alpha: alpha));
    l.painter.paint(canvas, Offset.zero);
    canvas.restore();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle = animate
          ? (0.5 + 0.5 * math.sin(t * 2 * math.pi * star.speed + star.phase))
          : 0.6;
      final paint = Paint()
        ..color =
            AppPalette.textSecondary.withValues(alpha: 0.10 + 0.22 * twinkle);
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height),
          star.radius, paint);
    }

    for (final l in fore) {
      _paintLetter(canvas, size, l, glowBoost: 1.0);
    }

    for (final l in mid) {
      _paintLetter(canvas, size, l, glowBoost: 1.4);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter oldDelegate) => oldDelegate.t != t;
}
