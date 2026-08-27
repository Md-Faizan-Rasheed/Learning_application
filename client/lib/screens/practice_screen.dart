import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/game_api.dart';
import '../l10n/app_localizations.dart';
import '../services/sound_service.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';

const _kSessionLength = 8;

class PracticeScreen extends StatefulWidget {
  const PracticeScreen(
      {super.key, required this.lang, this.category = 'mixed'});

  /// Current language code (en/ur/ar) so the server returns the right text.
  final String lang;
  final String category;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final GameApi _api = GameApi();

  bool _loading = true;
  String? _error;

  ServedQuestion? _question;
  int? _selectedIndex;
  DateTime? _shownAt; // when the question appeared, for response timing
  AnswerResult? _result; // null until answered
  bool _submitting = false;

  int _questionsAnswered = 0;
  int _correctCount = 0;
  int _sessionXp = 0;
  bool _sessionComplete = false;

  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _restartSession() {
    setState(() {
      _questionsAnswered = 0;
      _correctCount = 0;
      _sessionXp = 0;
      _sessionComplete = false;
    });
    _load();
  }

  void _nextQuestion() {
    if (_questionsAnswered >= _kSessionLength) {
      setState(() => _sessionComplete = true);
      if (_correctCount >= (_kSessionLength * 0.6).ceil()) {
        _confetti.play();
      }
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _selectedIndex = null;
    });
    try {
      final q = await _api.fetchPracticeQuestion(lang: widget.lang);
      setState(() {
        _question = q;
        _shownAt = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final q = _question;
    if (q == null || _selectedIndex == null) return;
    setState(() => _submitting = true);
    final elapsed = DateTime.now().difference(_shownAt!).inMilliseconds;
    try {
      final result = await _api.submitAnswer(
        matchId: q.matchId,
        questionId: q.questionId,
        chosenIndex: _selectedIndex,
        responseMs: elapsed,
      );
      setState(() {
        _result = result;
        _submitting = false;
        _questionsAnswered++;
        _sessionXp += result.pointsAwarded;
        if (result.isCorrect) _correctCount++;
      });
      if (result.isCorrect) {
        HapticFeedback.lightImpact();
        SoundService.instance.playCorrect();
      } else {
        HapticFeedback.mediumImpact();
        SoundService.instance.playIncorrect();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(title: t.practice),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          _sessionComplete ? _buildSessionSummary(context) : _buildBody(t),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            gravity: 0.3,
            shouldLoop: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSummary(BuildContext context) {
    final accuracy =
        _questionsAnswered == 0 ? 0.0 : _correctCount / _questionsAnswered;
    final colors = Theme.of(context).colorScheme;

    return Center(
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
                      'Session complete!',
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
                        _SummaryStat(
                          value: '$_correctCount/$_questionsAnswered',
                          label: 'Correct',
                        ),
                        _SummaryStat(
                          value: '${(accuracy * 100).round()}%',
                          label: 'Accuracy',
                        ),
                        _SummaryStat(
                          value: '+$_sessionXp',
                          label: 'Points',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _restartSession,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Play again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_loading) {
      return LoadingView(
        message: t.loadingQuestion,
        icon: Icons.quiz_rounded,
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(t.retry),
              ),
            ],
          ),
        ),
      );
    }

    final q = _question!;
    final answered = _result != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? 0.0
            : (constraints.maxWidth >= 600 ? 32.0 : 20.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 24, horizontalPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_questionsAnswered + 1} of $_kSessionLength',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        q.prompt,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(q.options.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _OptionTile(
                        text: q.options[i],
                        selected: _selectedIndex == i,
                        // colour only appears after answering (server verdict)
                        state: !answered
                            ? _OptionState.neutral
                            : i == _result!.correctIndex
                                ? _OptionState.correct
                                : (i == _selectedIndex
                                    ? _OptionState.wrong
                                    : _OptionState.neutral),
                        onTap: answered
                            ? null
                            : () => setState(() => _selectedIndex = i),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  if (!answered)
                    FilledButton(
                      onPressed: _selectedIndex == null || _submitting
                          ? null
                          : _submit,
                      child: Text(_submitting ? '…' : t.submit),
                    )
                  else ...[
                    _ResultBanner(result: _result!, t: t),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        _questionsAnswered >= _kSessionLength
                            ? 'See results'
                            : t.nextQuestion,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _OptionState { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color? border;
    switch (state) {
      case _OptionState.correct:
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
        break;
      case _OptionState.wrong:
        bg = Colors.red.withValues(alpha: 0.15);
        border = Colors.red;
        break;
      case _OptionState.neutral:
        bg = selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : null;
        border = selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border ?? Colors.grey, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.t});

  final AnswerResult result;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final ok = result.isCorrect;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel,
                  color: ok ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(
                ok ? t.correct : t.incorrect,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!ok) Text(t.correctAnswerIs(result.correctOption)),
          Text(t.pointsEarned(result.pointsAwarded)),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
        ),
      ],
    );
  }
}
