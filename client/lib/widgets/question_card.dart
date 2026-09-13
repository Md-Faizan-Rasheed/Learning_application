import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'option_tile.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final Function(int)? onOptionSelected;
  final int? selectedIndex;
  final int? correctIndex;

  /// Amplifies the correct-answer pop/glow — forwarded straight to
  /// [OptionTile.comboBoost] so multiplayer's combo streak reads the same
  /// way practice's does.
  final double comboBoost;

  const QuestionCard({
    Key? key,
    required this.question,
    required this.options,
    this.onOptionSelected,
    this.selectedIndex,
    this.correctIndex,
    this.comboBoost = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final revealed = correctIndex != null;

    return Card(
      elevation: 2,
      shadowColor: AppPalette.shadowInk,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: OptionTile(
                  text: options[i],
                  selected: selectedIndex == i,
                  index: i,
                  comboBoost: comboBoost,
                  state: !revealed
                      ? OptionState.neutral
                      : i == correctIndex
                          ? OptionState.correct
                          : (i == selectedIndex
                              ? OptionState.wrong
                              : OptionState.neutral),
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
