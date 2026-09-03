import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _decorativeGlyphs = ['ﻉ', 'ﺱ', 'ﻡ', 'ﻥ', 'ﻙ'];

class _Star {
  _Star(
      {required this.dx,
      required this.dy,
      required this.radius,
      required this.phase,
      required this.speed});
  final double dx, dy, radius, phase, speed;
}

class _Particle {
  _Particle(
      {required this.dx,
      required this.dy0,
      required this.size,
      required this.speed,
      required this.drift});
  final double dx, dy0, size, speed, drift;
}

class _Glyph {
  _Glyph(
      {required this.painter,
      required this.dx,
      required this.dy,
      required this.phase});
  final TextPainter painter;
  final double dx, dy, phase;
}

/// Full-bleed animated night sky: twinkling stars, slow-drifting particles,
/// a couple of soft blurred "floating islands," and a handful of decorative
/// Arabic glyphs — all painted on one canvas via one shared AnimationController
/// so the widget cost stays flat regardless of element count.
class AnimatedNightBackground extends StatefulWidget {
  const AnimatedNightBackground({super.key});

  @override
  State<AnimatedNightBackground> createState() =>
      _AnimatedNightBackgroundState();
}

class _AnimatedNightBackgroundState extends State<AnimatedNightBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;
  late final List<_Particle> _particles;
  late final List<_Glyph> _glyphs;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 24));
    final rng = math.Random(7);

    _stars = List.generate(
      46,
      (_) => _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.4,
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.6 + rng.nextDouble() * 0.8,
      ),
    );

    _particles = List.generate(
      12,
      (_) => _Particle(
        dx: rng.nextDouble(),
        dy0: rng.nextDouble(),
        size: 1.5 + rng.nextDouble() * 2.5,
        speed: 0.06 + rng.nextDouble() * 0.10,
        drift: (rng.nextDouble() - 0.5) * 0.04,
      ),
    );

    _glyphs = List.generate(_decorativeGlyphs.length, (i) {
      final painter = TextPainter(
        text: TextSpan(
          text: _decorativeGlyphs[i],
          style: TextStyle(
              fontSize: 30 + rng.nextDouble() * 18,
              color: AppPalette.gold,
              fontWeight: FontWeight.w300),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return _Glyph(
          painter: painter,
          dx: 0.08 + rng.nextDouble() * 0.84,
          dy: 0.08 + rng.nextDouble() * 0.84,
          phase: rng.nextDouble() * math.pi * 2);
    });
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

    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.nightTop, AppPalette.nightBottom],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _NightSkyPainter(
              t: reduceMotion ? 0 : _controller.value,
              animate: !reduceMotion,
              stars: _stars,
              particles: _particles,
              glyphs: _glyphs,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter(
      {required this.t,
      required this.animate,
      required this.stars,
      required this.particles,
      required this.glyphs});

  final double t;
  final bool animate;
  final List<_Star> stars;
  final List<_Particle> particles;
  final List<_Glyph> glyphs;

  @override
  void paint(Canvas canvas, Size size) {
    // Floating islands — soft blurred glow shapes.
    final islandPositions = [
      Offset(size.width * 0.16, size.height * 0.22),
      Offset(size.width * 0.82, size.height * 0.62)
    ];
    for (var i = 0; i < islandPositions.length; i++) {
      final bob = animate ? math.sin((t * 2 * math.pi) + i * 2.1) * 10 : 0.0;
      final center = islandPositions[i] + Offset(0, bob);
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, 90,
            [AppPalette.violet.withValues(alpha: 0.16), Colors.transparent])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, 90, paint);
    }

    // Stars.
    for (final star in stars) {
      final twinkle = animate
          ? (0.5 + 0.5 * math.sin(t * 2 * math.pi * star.speed + star.phase))
          : 0.7;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25 + 0.55 * twinkle);
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height),
          star.radius, paint);
    }

    // Drifting particles (wrap vertically).
    for (final p in particles) {
      final travelled = animate ? (t * p.speed) % 1.0 : 0.0;
      final dy = (p.dy0 - travelled) % 1.0;
      final dx = (p.dx +
              (animate ? math.sin(t * 2 * math.pi + p.dy0 * 10) * p.drift : 0))
          .clamp(0.0, 1.0);
      final alpha = (math.sin(dy * math.pi)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = AppPalette.teal.withValues(alpha: 0.35 * alpha);
      canvas.drawCircle(
          Offset(dx * size.width, dy * size.height), p.size, paint);
    }

    // Decorative Arabic glyphs, slowly fading in/out. The layer paint's
    // alpha modulates the whole glyph's opacity regardless of its own color,
    // so a single precomputed TextPainter (laid out once in initState) can
    // still fade smoothly frame to frame without re-laying-out text.
    for (final g in glyphs) {
      final alpha = animate
          ? (0.10 +
              0.10 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 0.5 + g.phase)))
          : 0.14;
      final origin = Offset(g.dx * size.width, g.dy * size.height);
      final bounds = Rect.fromLTWH(
          origin.dx, origin.dy, g.painter.width, g.painter.height);
      canvas.saveLayer(
          bounds, Paint()..color = Colors.white.withValues(alpha: alpha));
      g.painter.paint(canvas, origin);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NightSkyPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _RingDotsPainter extends CustomPainter {
  _RingDotsPainter({required this.color});
  final Color color;
  static const count = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i;
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
          offset, 2.4, Paint()..color = color.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(covariant _RingDotsPainter oldDelegate) => false;
}

/// The glowing portal — the screen's visual focal point. `intensity` (0-1)
/// brightens the glow (driven by field focus); `spinFast` speeds up the
/// rotation (driven by form submission); `burstSignal` fires a one-off
/// sparkle burst whenever it changes (driven by success).
class GlowingPortal extends StatefulWidget {
  const GlowingPortal({
    super.key,
    required this.size,
    this.intensity = 0.4,
    this.spinFast = false,
    this.burstSignal = 0,
  });

  final double size;
  final double intensity;
  final bool spinFast;
  final int burstSignal;

  @override
  State<GlowingPortal> createState() => _GlowingPortalState();
}

class _GlowingPortalState extends State<GlowingPortal>
    with TickerProviderStateMixin {
  late final AnimationController _rotate;
  late final AnimationController _pulse;
  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _rotate =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _sparkle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scheduleAmbientSparkle();
  }

  void _scheduleAmbientSparkle() {
    Future.delayed(Duration(seconds: 5 + math.Random().nextInt(4)), () {
      if (!mounted) return;
      _sparkle.forward(from: 0).then((_) {
        if (mounted) _scheduleAmbientSparkle();
      });
    });
  }

  @override
  void didUpdateWidget(covariant GlowingPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinFast != widget.spinFast) {
      _rotate.duration = Duration(seconds: widget.spinFast ? 3 : 18);
      if (_rotate.isAnimating) {
        _rotate.repeat();
      }
    }
    if (oldWidget.burstSignal != widget.burstSignal) {
      _sparkle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _rotate.dispose();
    _pulse.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_rotate.isAnimating) _rotate.stop();
      if (_pulse.isAnimating) _pulse.stop();
    } else {
      if (!_rotate.isAnimating) _rotate.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotate, _pulse, _sparkle]),
        builder: (context, _) {
          final pulseT = reduceMotion ? 0.5 : _pulse.value;
          final glow = (0.55 + 0.45 * pulseT) *
              (0.55 + 0.45 * widget.intensity.clamp(0.0, 1.0));

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.emerald.withValues(alpha: glow * 0.45),
                      AppPalette.violet.withValues(alpha: glow * 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              if (!reduceMotion)
                Transform.rotate(
                  angle: _rotate.value * 2 * math.pi,
                  child: SizedBox(
                    width: widget.size * 0.86,
                    height: widget.size * 0.86,
                    child: CustomPaint(
                        painter: _RingDotsPainter(color: AppPalette.gold)),
                  ),
                ),
              Container(
                width: widget.size * 0.52,
                height: widget.size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.portalCore,
                      AppPalette.teal.withValues(alpha: 0.7),
                      AppPalette.violet.withValues(alpha: 0.0)
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppPalette.teal.withValues(alpha: glow * 0.6),
                        blurRadius: 30,
                        spreadRadius: 4)
                  ],
                ),
              ),
              Icon(Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: widget.size * 0.16),
              if (!reduceMotion && _sparkle.value > 0 && _sparkle.value < 1)
                Opacity(
                  opacity: 1 - _sparkle.value,
                  child: Container(
                    width: widget.size * (0.6 + 0.5 * _sparkle.value),
                    height: widget.size * (0.6 + 0.5 * _sparkle.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppPalette.gold.withValues(alpha: 0.6),
                          width: 1.4),
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
