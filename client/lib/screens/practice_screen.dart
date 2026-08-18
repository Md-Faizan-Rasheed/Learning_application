import 'package:flutter/material.dart';

import '../api/game_api.dart';
import '../l10n/app_localizations.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.lang});

  /// Current language code (en/ur/ar) so the server returns the right text.
  final String lang;

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

  @override
  void initState() {
    super.initState();
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
      });
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
      appBar: AppBar(title: Text(t.practice)),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(t.loadingQuestion),
          ],
        ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q.prompt,
            style: Theme.of(context).textTheme.headlineSmall,
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
                onTap: answered ? null : () => setState(() => _selectedIndex = i),
              ),
            );
          }),
          const SizedBox(height: 24),
          if (!answered)
            FilledButton(
              onPressed:
                  _selectedIndex == null || _submitting ? null : _submit,
              child: Text(_submitting ? '…' : t.submit),
            )
          else ...[
            _ResultBanner(result: _result!, t: t),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.arrow_forward),
              label: Text(t.nextQuestion),
            ),
          ],
        ],
      ),
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