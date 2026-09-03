import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

/// One value/label pair shown in a [SessionCompleteCard]'s stat row.
class StatItem {
  const StatItem({required this.value, required this.label});
  final String value;
  final String label;
}

/// The gradient trophy card shown when a practice session or a teacher-
/// assigned quiz is finished — shared so both flows get the same celebration
/// (including confetti) instead of practice keeping the full treatment and
/// everything else getting a plainer stand-in.
class SessionCompleteCard extends StatefulWidget {
  const SessionCompleteCard({
    super.key,
    required this.title,
    required this.stats,
    required this.celebrate,
    required this.buttonLabel,
    required this.onButtonPressed,
    this.buttonIcon = Icons.refresh_rounded,
    this.shareText,
  });

  final String title;
  final List<StatItem> stats;

  /// Whether this completion is good enough to fire confetti (e.g. practice
  /// only celebrates at ≥60% accuracy — not every finish is a celebration).
  final bool celebrate;
  final String buttonLabel;
  final VoidCallback onButtonPressed;
  final IconData buttonIcon;

  /// When set, shows a "share" action that opens the OS share sheet with
  /// this text. Left to the caller so this generic card stays unaware of
  /// what kind of session (practice, teacher quiz, …) produced it.
  final String? shareText;

  @override
  State<SessionCompleteCard> createState() => _SessionCompleteCardState();
}

class _SessionCompleteCardState extends State<SessionCompleteCard> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.celebrate) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.primary, colors.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            color: Colors.white, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final s in widget.stats)
                              Expanded(
                                  child: _Stat(value: s.value, label: s.label)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.onButtonPressed,
                    icon: Icon(widget.buttonIcon),
                    label: Text(widget.buttonLabel),
                  ),
                  if (widget.shareText != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Share.share(widget.shareText!),
                      icon: const Icon(Icons.share_rounded),
                      label: Text(AppLocalizations.of(context)!.share),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          gravity: 0.3,
          shouldLoop: false,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
        ),
      ],
    );
  }
}
