import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/game_api.dart';
import '../api/social_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';
import '../widgets/option_tile.dart';
import '../widgets/question_flip_transition.dart';
import '../widgets/result_banner.dart';
import '../widgets/session_complete_card.dart';

const _kSessionLength = 8;

/// Whole-card "hit-stop" punch on a correct answer — a small, quick scale
/// bump (not the tile's own pop) so the reveal reads on the whole question,
/// not just the tapped option.
final _cardPunchTween = TweenSequence<double>([
  TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.03).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30),
  TweenSequenceItem(
      tween: Tween(begin: 1.03, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 70),
]);

/// One in-flight "+N" popup floating up from the answered question.
class _FloatingScore {
  _FloatingScore(this.id, this.points);
  final int id;
  final int points;
}

/// Rises and fades over [duration], then reports itself done so the caller
/// can drop it from the list — a fire-and-forget visual, not a real overlay
/// route.
class _FloatingScoreText extends StatefulWidget {
  const _FloatingScoreText({super.key, required this.points, required this.onDone});
  final int points;
  final VoidCallback onDone;

  @override
  State<_FloatingScoreText> createState() => _FloatingScoreTextState();
}

class _FloatingScoreTextState extends State<_FloatingScoreText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_c.value);
          return Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -46 * t),
                child: Center(
                  child: Text(
                    '+${widget.points}',
                    style: const TextStyle(
                      color: AppPalette.mutedGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.lang,
    this.category = 'mixed',
    this.challengeId,
    this.questionCount,
    this.token,
    this.myUserId,
  });

  /// Current language code (en/ur/ar) so the server returns the right text.
  final String lang;
  final String category;

  /// When set, this session is playing out a friend challenge: on
  /// completion the tally is reported to `SocialApi.submitChallengeScore`
  /// instead of just being shown locally. [token] and [myUserId] are
  /// required in that case (normal practice needs neither, since
  /// `/play/*` doesn't require auth).
  final String? challengeId;
  final int? questionCount;
  final String? token;
  final String? myUserId;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  final GameApi _api = GameApi();
  final SocialApi _socialApi = SocialApi();

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

  // Consecutive-correct streak within this session — escalates the reveal
  // (bigger pop/glow, higher-pitched sound) as it grows, and resets on a miss.
  int _streak = 0;

  final _scrollController = ScrollController();
  late final AnimationController _cardPunch;
  final List<_FloatingScore> _floatingScores = [];
  int _nextFloatingId = 0;

  Challenge? _challengeResult;
  bool _submittingChallenge = false;
  String? _challengeSubmitError;

  int get _sessionLength => widget.questionCount ?? _kSessionLength;

  /// 1.0 at no streak, ramping up to 1.4x by a streak of 5+ — used to scale
  /// both the tile pop/glow and the correct-sound pitch.
  double get _comboBoost => 1.0 + (_streak.clamp(0, 5) * 0.08);

  @override
  void initState() {
    super.initState();
    _cardPunch =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cardPunch.dispose();
    super.dispose();
  }

  void _restartSession() {
    setState(() {
      _questionsAnswered = 0;
      _correctCount = 0;
      _sessionXp = 0;
      _sessionComplete = false;
      _streak = 0;
    });
    _load();
  }

  void _nextQuestion() {
    if (_questionsAnswered >= _sessionLength) {
      setState(() => _sessionComplete = true);
      if (widget.challengeId != null) _submitChallengeScore();
      return;
    }
    _load();
  }

  Future<void> _submitChallengeScore() async {
    setState(() => _submittingChallenge = true);
    try {
      final result = await _socialApi.submitChallengeScore(
        widget.token!,
        widget.challengeId!,
        _correctCount,
      );
      setState(() {
        _challengeResult = result;
        _submittingChallenge = false;
      });
    } catch (e) {
      setState(() {
        _challengeSubmitError = e.toString();
        _submittingChallenge = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _selectedIndex = null;
    });
    try {
      final q = await _api.fetchPracticeQuestion(
          lang: widget.lang, category: widget.category);
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
        if (result.isCorrect) {
          _correctCount++;
          _streak++;
        } else {
          _streak = 0;
        }
      });
      if (result.isCorrect) {
        HapticFeedback.lightImpact();
        SoundService.instance.playCorrect(pitch: 1.0 + (_streak.clamp(0, 5) * 0.05));
        _cardPunch.forward(from: 0);
        if (result.pointsAwarded > 0) {
          final id = _nextFloatingId++;
          setState(() => _floatingScores.add(_FloatingScore(id, result.pointsAwarded)));
        }
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
      appBar: AppHeader(
        title: t.practice,
        scrollController: _sessionComplete
            ? (widget.challengeId != null ? _scrollController : null)
            : ((_loading || _error != null) ? null : _scrollController),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
              child:
                  _sessionComplete ? _buildSessionSummary(t) : _buildBody(t)),
        ],
      ),
    );
  }

  Widget _buildSessionSummary(AppLocalizations t) {
    final accuracy =
        _questionsAnswered == 0 ? 0.0 : _correctCount / _questionsAnswered;
    final isChallenge = widget.challengeId != null;
    final card = SessionCompleteCard(
      title: t.practiceSessionComplete,
      celebrate: _correctCount >= (_sessionLength * 0.6).ceil(),
      stats: [
        StatItem(
            value: '$_correctCount/$_questionsAnswered',
            label: t.practiceCorrectLabel),
        StatItem(
            value: '${(accuracy * 100).round()}%',
            label: t.practiceAccuracyLabel),
        StatItem(value: '+$_sessionXp', label: t.practicePointsLabel),
      ],
      buttonLabel: isChallenge ? t.challengeDone : t.practicePlayAgain,
      onButtonPressed: isChallenge
          ? () => Navigator.of(context).pop(_challengeResult)
          : _restartSession,
      shareText: t.practiceShareText(
          _correctCount, _questionsAnswered, _sessionXp, t.appTitle),
    );

    if (!isChallenge) return card;

    return Center(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            card,
            const SizedBox(height: 16),
            _buildChallengeOutcome(t),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeOutcome(AppLocalizations t) {
    if (_submittingChallenge) {
      return const CircularProgressIndicator();
    }
    if (_challengeSubmitError != null) {
      return Text(
        _challengeSubmitError!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppPalette.incorrectRed),
      );
    }
    final c = _challengeResult;
    if (c == null) return const SizedBox.shrink();

    final iAmChallenger = c.challengerId == widget.myUserId;
    final opponentName = iAmChallenger ? c.opponentName : c.challengerName;

    if (c.status == 'pending') {
      return Text(t.challengeWaitingOn(opponentName),
          textAlign: TextAlign.center);
    }
    if (c.winnerId == null) {
      return Text(t.challengeTied, textAlign: TextAlign.center);
    }
    final iWon = c.winnerId == widget.myUserId;
    return Text(
      iWon ? t.challengeYouWon(opponentName) : t.challengeYouLost(opponentName),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
              const Icon(Icons.error, color: AppPalette.incorrectRed, size: 48),
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
              child: Stack(
                children: [
                  QuestionFlipTransition(
                    flipKey: q.questionId,
                    child: Column(
                      key: ValueKey(q.questionId),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.practiceQuestionProgress(
                              _questionsAnswered + 1, _sessionLength),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _cardPunch,
                          builder: (context, child) => Transform.scale(
                            scale: _cardPunchTween.evaluate(_cardPunch),
                            child: child,
                          ),
                          child: Card(
                            elevation: 2,
                            shadowColor: AppPalette.shadowInk,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                q.prompt,
                                style: Theme.of(context).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
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
                              // colour only appears after answering (server verdict)
                              state: !answered
                                  ? OptionState.neutral
                                  : i == _result!.correctIndex
                                      ? OptionState.correct
                                      : (i == _selectedIndex
                                          ? OptionState.wrong
                                          : OptionState.neutral),
                              comboBoost: _comboBoost,
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
                            onPressed: _nextQuestion,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              _questionsAnswered >= _sessionLength
                                  ? t.practiceSeeResults
                                  : t.nextQuestion,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final f in _floatingScores)
                    _FloatingScoreText(
                      key: ValueKey(f.id),
                      points: f.points,
                      onDone: () {
                        if (mounted) {
                          setState(() =>
                              _floatingScores.removeWhere((e) => e.id == f.id));
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
