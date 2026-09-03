import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final Function(int)? onOptionSelected;
  final int? selectedIndex;
  final int? correctIndex;

  const QuestionCard({
    Key? key,
    required this.question,
    required this.options,
    this.onOptionSelected,
    this.selectedIndex,
    this.correctIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final revealed = correctIndex != null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _OptionTile(
                  text: options[i],
                  selected: selectedIndex == i,
                  isCorrect: revealed && i == correctIndex,
                  isWrongPick:
                      revealed && selectedIndex == i && i != correctIndex,
                  onTap: onOptionSelected == null
                      ? null
                      : () => onOptionSelected!(i),
                ),
              ),
            if (revealed && selectedIndex == null) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.qcTimeUp,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
              ),
            ] else if (!revealed &&
                selectedIndex != null &&
                onOptionSelected == null) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.qcAnswerLocked,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.selected,
    required this.isCorrect,
    required this.isWrongPick,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool isCorrect;
  final bool isWrongPick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Color? bg;
    Color border;
    Widget? trailing;

    if (isCorrect) {
      bg = Colors.green.withValues(alpha: 0.14);
      border = Colors.green;
      trailing = const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (isWrongPick) {
      bg = Colors.red.withValues(alpha: 0.14);
      border = Colors.red;
      trailing = const Icon(Icons.cancel, color: Colors.red, size: 20);
    } else if (selected) {
      bg = colors.primary.withValues(alpha: 0.12);
      border = colors.primary;
    } else {
      border = colors.outlineVariant;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
