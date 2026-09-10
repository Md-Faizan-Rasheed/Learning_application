import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../realtime/match_socket.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/option_tile.dart';

/// Post-match review: every question the match asked, with the player's own
/// pick and the correct answer marked. Built entirely from [entries] — data
/// already broadcast round-by-round during the match — so opening this
/// screen needs no extra request to the server.
class MatchReportScreen extends StatelessWidget {
  const MatchReportScreen({
    super.key,
    required this.lang,
    required this.entries,
  });

  final String lang;
  final List<MatchReportEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(title: t.mpMatchReportTitle),
      body: ScreenWithAmbientBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900
                ? 0.0
                : (constraints.maxWidth >= 600 ? 32.0 : 16.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 16, horizontalPadding, 24),
                  children: [
                    Text(
                      t.mpReportLegend,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final entry in entries) ...[
                      _ReportQuestionCard(lang: lang, entry: entry),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportQuestionCard extends StatelessWidget {
  const _ReportQuestionCard({required this.lang, required this.entry});

  final String lang;
  final MatchReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final options = entry.question.optionsFor(lang);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.mpQuestionNumber(entry.roundNo + 1),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  entry.isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: entry.isCorrect ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.question.promptFor(lang),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OptionTile(
                  text: options[i],
                  selected: entry.myChosenIndex == i,
                  state: i == entry.correctIndex
                      ? OptionState.correct
                      : (i == entry.myChosenIndex
                          ? OptionState.wrong
                          : OptionState.neutral),
                  onTap: null,
                ),
              ),
            if (entry.myChosenIndex == null) ...[
              const SizedBox(height: 6),
              Text(
                t.mpReportNotAnswered,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
