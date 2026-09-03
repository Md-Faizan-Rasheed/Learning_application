import 'package:flutter/material.dart';

import '../../api/classroom_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/option_tile.dart';
import '../../widgets/result_banner.dart';
import '../../widgets/session_complete_card.dart';

class TeacherQuizScreen extends StatefulWidget {
  const TeacherQuizScreen({
    super.key,
    required this.token,
    required this.quizId,
    required this.lang,
  });

  final String token;
  final String quizId;
  final String lang;

  @override
  State<TeacherQuizScreen> createState() => _TeacherQuizScreenState();
}

class _TeacherQuizScreenState extends State<TeacherQuizScreen> {
  final ClassroomApi _api = ClassroomApi();

  bool _loading = true;
  String? _error;

  ServedQuizQuestion? _question;
  int? _selectedIndex;
  DateTime? _shownAt;
  QuizAnswerResult? _result;
  bool _submitting = false;

  QuizResult? _finalResult;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _selectedIndex = null;
    });
    try {
      final q =
          await _api.startQuiz(widget.token, widget.quizId, lang: widget.lang);
      setState(() {
        _question = q;
        _shownAt = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      // The quiz may already be complete (409) — show the final result instead.
      try {
        final r = await _api.getResult(widget.token, widget.quizId);
        setState(() {
          _finalResult = r;
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final q = _question;
    if (q == null || _selectedIndex == null) return;
    setState(() => _submitting = true);
    final elapsed = DateTime.now().difference(_shownAt!).inMilliseconds;
    try {
      final result = await _api.answerQuestion(
        widget.token,
        widget.quizId,
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

  Future<void> _next() async {
    if (_result?.quizComplete == true) {
      setState(() => _loading = true);
      try {
        final r = await _api.getResult(widget.token, widget.quizId);
        setState(() {
          _finalResult = r;
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.studentAssignedQuizzesTitle,
        scrollController: (_finalResult != null || _loading || _error != null)
            ? null
            : _scrollController,
      ),
      body: ScreenWithAmbientBackdrop(
        child: _finalResult != null ? _buildFinalResult(t) : _buildBody(t),
      ),
    );
  }

  Widget _buildFinalResult(AppLocalizations t) {
    final r = _finalResult!;
    final celebrate = r.totalQuestions > 0 &&
        r.correctCount >= (r.totalQuestions * 0.6).ceil();
    return SessionCompleteCard(
      title: t.studentQuizComplete,
      celebrate: celebrate,
      stats: [
        StatItem(
            value: '${r.correctCount}/${r.totalQuestions}',
            label: t.practiceCorrectLabel),
        StatItem(value: '+${r.score}', label: t.practicePointsLabel),
      ],
      buttonLabel: t.studentBackToQuizzes,
      buttonIcon: Icons.arrow_back,
      onButtonPressed: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_loading) {
      return LoadingView(message: t.loadingQuestion, icon: Icons.quiz_rounded);
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
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 24, horizontalPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.practiceQuestionProgress(q.questionNo, q.totalQuestions),
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
                      child: OptionTile(
                        text: q.options[i],
                        selected: _selectedIndex == i,
                        state: !answered
                            ? OptionState.neutral
                            : i == _result!.correctIndex
                                ? OptionState.correct
                                : (i == _selectedIndex
                                    ? OptionState.wrong
                                    : OptionState.neutral),
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
                    ResultBanner(
                      isCorrect: _result!.isCorrect,
                      correctOption: _result!.correctOption,
                      pointsAwarded: _result!.pointsAwarded,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_result!.quizComplete
                          ? t.practiceSeeResults
                          : t.nextQuestion),
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
