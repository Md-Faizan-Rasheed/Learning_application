import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single place to tune walkthrough motion and highlight colors.
class OnboardingMotion {
  OnboardingMotion._();

  static const entry = Duration(milliseconds: 320);
  static const move = Duration(milliseconds: 360);
  static const exit = Duration(milliseconds: 240);
  static const press = Duration(milliseconds: 110);
  static const reducedExit = Duration(milliseconds: 140);
  static const successCue = Duration(milliseconds: 420);
  static const reducedSuccessCue = Duration(milliseconds: 220);
  static const pulse = Duration(milliseconds: 1500);
  static const preview = Duration(milliseconds: 1800);
  static const titleFade = Interval(0.12, 0.62, curve: Curves.easeOut);
  static const descriptionFade = Interval(0.26, 0.78, curve: Curves.easeOut);
  static const controlsFade = Interval(0.42, 1, curve: Curves.easeOut);
  static const curve = Curves.easeInOutCubic;
  static const enterCurve = Curves.easeOutCubic;
  static const scrim = Color(0xD9001112);
  static const spotlight = Color(0xFFB9E4D1);
  static const radius = 18.0;
}

class OnboardingStep {
  const OnboardingStep({
    required this.target,
    required this.title,
    required this.description,
    required this.icon,
    required this.visual,
  });

  final GlobalKey target;
  final String title;
  final String description;
  final IconData icon;
  final OnboardingVisual visual;
}

enum OnboardingVisual {
  multiplayer,
  campaign,
  quickPlay,
  profile,
  leaderboard,
  learn
}

/// A lightweight coach-mark tour that highlights real widgets by GlobalKey.
class OnboardingTour extends StatefulWidget {
  const OnboardingTour({
    super.key,
    required this.steps,
    required this.skipLabel,
    required this.nextLabel,
    required this.backLabel,
    required this.finishLabel,
    required this.stepLabel,
    required this.doneTitle,
    required this.doneDescription,
    required this.onSkip,
    required this.onFinish,
  });

  final List<OnboardingStep> steps;
  final String skipLabel;
  final String nextLabel;
  final String backLabel;
  final String finishLabel;
  final String Function(int current, int total) stepLabel;
  final String doneTitle;
  final String doneDescription;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _cardController;
  late final AnimationController _pulseController;
  int _index = 0;
  Rect? _targetRect;
  Rect? _fromRect;
  bool _closing = false;
  bool _finished = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: OnboardingMotion.entry,
      value: 0,
    )..forward();
    _cardController = AnimationController(
      vsync: this,
      duration: OnboardingMotion.entry,
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: OnboardingMotion.pulse,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _pulseController.stop();
      _pulseController.value = 0;
    } else if (!_closing && !_finished && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _measureTarget() {
    if (!mounted || _index >= widget.steps.length) return;
    final targetContext = widget.steps[_index].target.currentContext;
    final overlayContext = context;
    final targetObject = targetContext?.findRenderObject();
    final overlayObject = overlayContext.findRenderObject();
    if (targetObject is! RenderBox ||
        !targetObject.hasSize ||
        overlayObject is! RenderBox ||
        !overlayObject.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
      return;
    }
    final globalOrigin = targetObject.localToGlobal(Offset.zero);
    final localOrigin = overlayObject.globalToLocal(globalOrigin);
    final rect = (localOrigin & targetObject.size).inflate(8);
    setState(() {
      _fromRect ??= _targetRect ??
          Rect.fromCenter(
            center: Offset(
                overlayObject.size.width / 2, overlayObject.size.height - 110),
            width: 54,
            height: 54,
          );
      _targetRect = rect;
    });
    _cardController.forward(from: 0);
  }

  void _setStep(int next) {
    if (next < 0 || next >= widget.steps.length || _closing) return;
    setState(() {
      _fromRect = _targetRect ?? _fromRect;
      _index = next;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  Future<void> _close({required bool completed}) async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _finished = completed;
    });
    _pulseController.stop();
    if (completed) {
      await Future<void>.delayed(_reduceMotion
          ? OnboardingMotion.reducedSuccessCue
          : OnboardingMotion.successCue);
    }
    _entryController.duration =
        _reduceMotion ? OnboardingMotion.reducedExit : OnboardingMotion.exit;
    await _entryController.reverse();
    if (!mounted) return;
    if (completed) {
      widget.onFinish();
    } else {
      widget.onSkip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final colors = Theme.of(context).colorScheme;
    final step = widget.steps[_index];
    final cardWidth = (size.width - 32).clamp(220.0, 360.0).toDouble();
    final fallbackRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 110),
      width: 54,
      height: 54,
    );
    final beginRect = _fromRect ?? _targetRect ?? fallbackRect;
    final endRect = _targetRect ?? beginRect;

    return Positioned.fill(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label:
            '${step.title}. ${widget.stepLabel(_index + 1, widget.steps.length)}',
        child: AnimatedBuilder(
          animation: _entryController,
          builder: (context, _) {
            final fade = CurvedAnimation(
              parent: _entryController,
              curve: OnboardingMotion.enterCurve,
            ).value;
            return Opacity(
              opacity: fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final safeTop = media.padding.top + 12;
                  final safeBottom = media.padding.bottom + 16;
                  final maxCardHeight = math.min(
                    (height * 0.58).clamp(150.0, 300.0).toDouble(),
                    math.max(80.0, height - safeTop - safeBottom),
                  );
                  return TweenAnimationBuilder<Rect>(
                    tween: _RectTween(begin: beginRect, end: endRect),
                    duration:
                        _reduceMotion ? Duration.zero : OnboardingMotion.move,
                    curve: OnboardingMotion.curve,
                    builder: (context, currentRect, _) {
                      final roomAbove = currentRect.top - safeTop;
                      final roomBelow =
                          height - currentRect.bottom - safeBottom;
                      final placeBelow =
                          roomAbove < maxCardHeight && roomBelow > roomAbove;
                      final preferredTop = placeBelow
                          ? currentRect.bottom + 18
                          : currentRect.top - maxCardHeight - 18;
                      final cardTop = preferredTop
                          .clamp(safeTop, height - maxCardHeight - safeBottom)
                          .toDouble();
                      final cardLeft = (currentRect.center.dx - cardWidth / 2)
                          .clamp(
                              16.0, math.max(16.0, size.width - cardWidth - 16))
                          .toDouble();
                      final tooltipOffset = _reduceMotion
                          ? Offset.zero
                          : Offset(0, (1 - fade) * 12);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const ModalBarrier(
                              color: Colors.transparent, dismissible: false),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _SpotlightPainter(
                                rect: currentRect,
                                color: OnboardingMotion.scrim
                                    .withValues(alpha: 0.84 * fade),
                                ringColor: OnboardingMotion.spotlight,
                                pulse: _pulseController,
                                reduceMotion: _reduceMotion,
                                arrowDown: !placeBelow,
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: Duration.zero,
                            left: cardLeft,
                            top: cardTop,
                            width: cardWidth,
                            child: Transform.translate(
                              offset: tooltipOffset,
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxHeight: maxCardHeight),
                                child: _TourCard(
                                  key: ValueKey<int>(_index),
                                  step: step,
                                  index: _index,
                                  count: widget.steps.length,
                                  skipLabel: widget.skipLabel,
                                  nextLabel: widget.nextLabel,
                                  backLabel: widget.backLabel,
                                  finishLabel: widget.finishLabel,
                                  stepLabel: widget.stepLabel(
                                      _index + 1, widget.steps.length),
                                  colors: colors,
                                  animation: _cardController,
                                  onSkip: () => _close(completed: false),
                                  onBack: () => _setStep(_index - 1),
                                  onNext: () {
                                    HapticFeedback.selectionClick();
                                    if (_index == widget.steps.length - 1) {
                                      _close(completed: true);
                                    } else {
                                      _setStep(_index + 1);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_finished)
                            Center(
                              child: _TourDoneCard(
                                title: widget.doneTitle,
                                description: widget.doneDescription,
                                color: colors.primary,
                                reduceMotion: _reduceMotion,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.skipLabel,
    required this.nextLabel,
    required this.backLabel,
    required this.finishLabel,
    required this.stepLabel,
    required this.colors,
    required this.animation,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  final OnboardingStep step;
  final int index;
  final int count;
  final String skipLabel;
  final String nextLabel;
  final String backLabel;
  final String finishLabel;
  final String stepLabel;
  final ColorScheme colors;
  final Animation<double> animation;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = index == count - 1;
    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(OnboardingMotion.radius),
            border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(step.icon, color: colors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(stepLabel,
                          textAlign: TextAlign.end,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  )),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: OnboardingMotion.titleFade),
                  child: Text(step.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          )),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation,
                      curve: OnboardingMotion.descriptionFade),
                  child: Text(step.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          )),
                ),
                const SizedBox(height: 12),
                _FeaturePreview(visual: step.visual, color: colors.primary),
                const SizedBox(height: 16),
                _TourProgress(
                  index: index,
                  count: count,
                  color: colors.primary,
                  label: stepLabel,
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: OnboardingMotion.controlsFade),
                  child: Row(
                    children: [
                      _PressFeedback(
                        child: TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                              minimumSize: const Size(64, 48)),
                          child: Text(skipLabel),
                        ),
                      ),
                      const Spacer(),
                      _PressFeedback(
                        child: TextButton(
                          onPressed: index > 0 ? onBack : null,
                          style: TextButton.styleFrom(
                              minimumSize: const Size(64, 48)),
                          child: Text(backLabel),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PressFeedback(
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(92, 48)),
                          child: Text(isLast ? finishLabel : nextLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative mini previews connect each step to the feature it highlights.
class _FeaturePreview extends StatefulWidget {
  const _FeaturePreview({required this.visual, required this.color});

  final OnboardingVisual visual;
  final Color color;

  @override
  State<_FeaturePreview> createState() => _FeaturePreviewState();
}

class _FeaturePreviewState extends State<_FeaturePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  Color get _color => widget.color;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: OnboardingMotion.preview);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion == reduceMotion &&
        _controller.isAnimating == !reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0.5;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double start, double end) {
    final value = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(value);
  }

  double _wave(double offset) =>
      math.sin((_controller.value * math.pi) + offset).abs();

  Widget _tile(IconData icon, {double scale = 1, double lift = 0}) =>
      Transform.translate(
        offset: Offset(0, -lift),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: _color),
          ),
        ),
      );

  Widget _connector(double progress) => SizedBox(
        width: 22,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(height: 2, color: _color.withValues(alpha: .5)),
          ),
        ),
      );

  Widget _statBar(double width, double progress) => SizedBox(
        width: width,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      );

  Widget _podium(Color shade, double height, double progress, IconData icon) =>
      Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleY: .78 + progress * .22,
        child: Container(
          width: 42,
          height: height,
          decoration: BoxDecoration(
            color: shade.withValues(alpha: .12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Icon(icon, size: 19, color: shade),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Center(child: _buildPreview(muted)),
        ),
      ),
    );
  }

  Widget _buildPreview(Color muted) {
    final beat = math.sin(_controller.value * math.pi);
    switch (widget.visual) {
      case OnboardingVisual.multiplayer:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _tile(Icons.person_rounded,
              scale: .94 + _wave(0) * .06, lift: _wave(0) * 2),
          const SizedBox(width: 8),
          Transform.scale(
            scale: .9 + beat * .2,
            child: Icon(Icons.bolt_rounded, color: _color, size: 20),
          ),
          const SizedBox(width: 8),
          _tile(Icons.groups_rounded,
              scale: .94 + _wave(math.pi / 2) * .06,
              lift: _wave(math.pi / 2) * 2),
        ]);
      case OnboardingVisual.campaign:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _tile(Icons.place_rounded, scale: .94 + _wave(0) * .06),
          _connector(_phase(0, .42)),
          _tile(Icons.menu_book_rounded, scale: .92 + _phase(.24, .58) * .08),
          _connector(_phase(.42, .82)),
          _tile(Icons.flag_rounded, scale: .92 + _phase(.6, 1) * .08),
        ]);
      case OnboardingVisual.quickPlay:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _tile(Icons.grid_view_rounded, lift: _wave(0) * 3),
          const SizedBox(width: 12),
          _tile(Icons.water_rounded, lift: _wave(math.pi / 2) * 3),
          const SizedBox(width: 12),
          _tile(Icons.quiz_rounded, lift: _wave(math.pi) * 3),
        ]);
      case OnboardingVisual.profile:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
            radius: 19 + beat,
            backgroundColor: _color.withValues(alpha: .12),
            child: Icon(Icons.person_rounded, color: _color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _statBar(72, .5 + _phase(.05, .75) * .45),
            const SizedBox(height: 6),
            _statBar(52, .35 + _phase(.2, .9) * .6),
          ]),
          const SizedBox(width: 12),
          Transform.scale(
            scale: .92 + _phase(.65, 1) * .08,
            child: Icon(Icons.verified_rounded, color: _color, size: 24),
          ),
        ]);
      case OnboardingVisual.leaderboard:
        return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _podium(
                  muted, 27, _phase(.18, .88), Icons.workspace_premium_rounded),
              const SizedBox(width: 8),
              _podium(_color, 39, _phase(0, .7), Icons.emoji_events_rounded),
              const SizedBox(width: 8),
              _podium(
                  muted, 22, _phase(.32, 1), Icons.workspace_premium_rounded),
            ]);
      case OnboardingVisual.learn:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Transform.translate(
            offset: Offset(0, -beat * 2),
            child: _tile(Icons.menu_book_rounded),
          ),
          const SizedBox(width: 14),
          _questMark(Icons.check_circle_rounded, _phase(0, .44)),
          const SizedBox(width: 6),
          _questMark(Icons.check_circle_rounded, _phase(.28, .72), alpha: .7),
          const SizedBox(width: 6),
          _questMark(Icons.radio_button_unchecked_rounded, 1, color: muted),
        ]);
    }
  }

  Widget _questMark(IconData icon, double scale,
          {double alpha = 1, Color? color}) =>
      Transform.scale(
        scale: scale.clamp(.75, 1),
        child: Icon(icon,
            color: color ?? _color.withValues(alpha: alpha), size: 20),
      );
}

class _TourDoneCard extends StatelessWidget {
  const _TourDoneCard(
      {required this.title,
      required this.description,
      required this.color,
      required this.reduceMotion});
  final String title;
  final String description;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: '$title. $description',
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(OnboardingMotion.radius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: reduceMotion ? 1 : 0.72,
                    end: 1,
                  ),
                  duration:
                      reduceMotion ? Duration.zero : OnboardingMotion.entry,
                  curve: OnboardingMotion.enterCurve,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child:
                      Icon(Icons.check_circle_rounded, color: color, size: 52),
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class _PressFeedback extends StatefulWidget {
  const _PressFeedback({required this.child});
  final Widget child;

  @override
  State<_PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<_PressFeedback> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduceMotion || !_pressed ? 1 : 0.97,
        duration: reduceMotion ? Duration.zero : OnboardingMotion.press,
        curve: OnboardingMotion.enterCurve,
        child: widget.child,
      ),
    );
  }
}

class _TourProgress extends StatelessWidget {
  const _TourProgress(
      {required this.index,
      required this.count,
      required this.color,
      required this.label});
  final int index;
  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: label,
      child: Row(
        children: List.generate(count, (i) {
          final active = i == index;
          return Expanded(
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : OnboardingMotion.move,
              curve: OnboardingMotion.curve,
              height: 6,
              margin: EdgeInsetsDirectional.only(end: i == count - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: active
                    ? color
                    : color.withValues(alpha: i < index ? 0.48 : 0.16),
                borderRadius: BorderRadius.circular(99),
              ),
              transform: Matrix4.diagonal3Values(active ? 1 : 0.94, 1, 1),
            ),
          );
        }),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.rect,
    required this.color,
    required this.ringColor,
    required this.pulse,
    required this.reduceMotion,
    required this.arrowDown,
  }) : super(repaint: pulse);

  final Rect rect;
  final Color color;
  final Color ringColor;
  final Animation<double> pulse;
  final bool reduceMotion;
  final bool arrowDown;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rounded);
    canvas.drawPath(shade, Paint()..color = color);
    final pulseValue = reduceMotion ? 0.0 : pulse.value;
    final spread = pulseValue * 5;
    canvas.drawRRect(
      rounded.inflate(spread),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ringColor.withValues(alpha: 0.28 + pulseValue * 0.42),
    );
    final arrowY = arrowDown
        ? rect.top - 9 - pulseValue * 2
        : rect.bottom + 9 + pulseValue * 2;
    final arrow = Path();
    if (arrowDown) {
      arrow
        ..moveTo(rect.center.dx - 6, arrowY - 4)
        ..lineTo(rect.center.dx, arrowY + 3)
        ..lineTo(rect.center.dx + 6, arrowY - 4);
    } else {
      arrow
        ..moveTo(rect.center.dx - 6, arrowY + 4)
        ..lineTo(rect.center.dx, arrowY - 3)
        ..lineTo(rect.center.dx + 6, arrowY + 4);
    }
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ringColor.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      rect != oldDelegate.rect ||
      color != oldDelegate.color ||
      pulse != oldDelegate.pulse ||
      reduceMotion != oldDelegate.reduceMotion ||
      arrowDown != oldDelegate.arrowDown;
}

class _RectTween extends Tween<Rect> {
  _RectTween({required super.begin, required super.end});

  @override
  Rect lerp(double t) => Rect.lerp(begin!, end!, t)!;
}
