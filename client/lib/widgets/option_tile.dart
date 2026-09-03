import 'package:flutter/material.dart';

/// Shared across every "answer a multiple-choice question" screen (practice,
/// teacher-assigned quizzes). Neutral until answered; the server's verdict
/// then colors it green/red — the client never decides correctness itself.
enum OptionState { neutral, correct, wrong }

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    late final Color border;
    switch (state) {
      case OptionState.correct:
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
        break;
      case OptionState.wrong:
        bg = Colors.red.withValues(alpha: 0.15);
        border = Colors.red;
        break;
      case OptionState.neutral:
        bg = selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : null;
        border = selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: state != OptionState.neutral
            ? [
                BoxShadow(
                  color: border.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (state == OptionState.correct)
                const Icon(Icons.check_circle_rounded, color: Colors.green)
              else if (state == OptionState.wrong)
                const Icon(Icons.cancel_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }
}
