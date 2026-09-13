import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'card_stock.dart';
import 'mark_painters.dart';

/// Shared "you got it / not quite" banner shown after an answer is graded.
/// Takes plain fields rather than a specific model type so it works for both
/// practice's AnswerResult and a teacher quiz's QuizAnswerResult alike.
class ResultBanner extends StatefulWidget {
  const ResultBanner({
    super.key,
    required this.isCorrect,
    required this.correctOption,
    required this.pointsAwarded,
  });

  final bool isCorrect;
  final String correctOption;
  final int pointsAwarded;

  @override
  State<ResultBanner> createState() => _ResultBannerState();
}

class _ResultBannerState extends State<ResultBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ok = widget.isCorrect;
    final tint = ok ? AppPalette.correctGold : AppPalette.incorrectRed;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: cardStockDecoration(
            borderRadius: 16,
            color: Color.alphaBlend(
                tint.withValues(alpha: 0.10), AppPalette.cardStock),
            borderColor: tint.withValues(alpha: 0.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: CustomPaint(
                        painter: ok
                            ? const CheckmarkPainter(
                                color: AppPalette.cardStock, strokeWidth: 2.4)
                            : const CrossPainter(
                                color: AppPalette.cardStock, strokeWidth: 2.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ok ? t.correct : t.incorrect,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!ok) Text(t.correctAnswerIs(widget.correctOption)),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.pointsAwarded),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, _) => Text(
                  t.pointsEarned(value),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
