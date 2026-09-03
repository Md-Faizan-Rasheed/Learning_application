import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shared "you got it / not quite" banner shown after an answer is graded.
/// Takes plain fields rather than a specific model type so it works for both
/// practice's AnswerResult and a teacher quiz's QuizAnswerResult alike.
class ResultBanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ok = isCorrect;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.35)),
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
                  color: ok ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                ok ? t.correct : t.incorrect,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!ok) Text(t.correctAnswerIs(correctOption)),
          Text(
            t.pointsEarned(pointsAwarded),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
