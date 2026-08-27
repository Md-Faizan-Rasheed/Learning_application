import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../realtime/match_socket.dart';
import '../services/sound_service.dart';
import '../widgets/app_header.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/leaderboard.dart';
import '../widgets/loading_view.dart';
import '../widgets/question_card.dart';
import '../widgets/reward_card.dart';

const kQuestionTimeMs = 20000;

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({
    super.key,
    required this.lang,
    required this.name,
    this.token,
    this.category = 'mixed',
  });

  final String lang;
  final String name;
  final String? token;
  final String category;

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen>
    with SingleTickerProviderStateMixin {
  final MatchSocket _socket = MatchSocket();

  bool _connecting = true;
  MatchQuestion? _question;

  int _remainingTimeMs = 0;
  bool _submitted = false;
  int? _selectedIndex;
  RoundResult? _roundResult;
  int _questionNumber = 0;
  int _combo = 0;

  final List<FinalStanding> _standings = [];

  Timer? _countdownTimer;
  late final ConfettiController _confetti;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);

    _confetti = ConfettiController(duration: const Duration(seconds: 3));

    _connect();
  }

  Future<void> _connect() async {
    if (!mounted) return;

    setState(() {
      _connecting = true;
    });

    final connected = await _socket.connect(
      token: widget.token,
    );

    if (!mounted) return;

    if (!connected) {
      setState(() {
        _connecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to multiplayer server'),
        ),
      );

      return;
    }

    _socket.on('question', _handleQuestion);
    _socket.on('round_result', _handleRoundOver);
    _socket.on('match_over', _handleMatchOver);
    _socket.on('resume_snapshot', _handleResumeSnapshot);

    _socket.findMatch(
      name: widget.name,
      category: widget.category,
    );

    setState(() {
      _connecting = false;
    });
  }

  void _handleQuestion(Map<String, dynamic> data) {
    if (!mounted) return;

    final question = MatchQuestion.fromJson(data);

    setState(() {
      _question = question;
      _remainingTimeMs = question.timeMs;
      _submitted = false;
      _selectedIndex = null;
      _roundResult = null;
      _questionNumber++;
      _standings.clear();
    });

    _startCountdown(question.timeMs);
  }

  void _startCountdown(int durationMs) {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final wasAboveThreshold = _remainingTimeMs > 5000;

        setState(() {
          _remainingTimeMs -= 100;

          if (_remainingTimeMs <= 0) {
            _remainingTimeMs = 0;
            timer.cancel();
          }
        });

        if (wasAboveThreshold && _remainingTimeMs <= 5000) {
          SoundService.instance.playCountdown();
        }
      },
    );
  }

  void _handleRoundOver(Map<String, dynamic> data) {
    if (!mounted) return;

    final result = RoundResult.fromJson(data);
    final wasCorrect =
        _selectedIndex != null && _selectedIndex == result.correctIndex;

    setState(() {
      _roundResult = result;
      _combo = wasCorrect ? _combo + 1 : 0;
    });

    if (_selectedIndex != null) {
      if (wasCorrect) {
        HapticFeedback.lightImpact();
        SoundService.instance.playCorrect();
      } else {
        HapticFeedback.mediumImpact();
        SoundService.instance.playIncorrect();
      }
    }
  }

  void _handleMatchOver(Map<String, dynamic> data) {
    if (!mounted) return;

    final rawStandings = data['standings'];

    if (rawStandings is! List) {
      return;
    }

    final standings = rawStandings
        .whereType<Map>()
        .map(
          (item) => FinalStanding.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    _countdownTimer?.cancel();

    setState(() {
      _standings
        ..clear()
        ..addAll(standings);
    });

    FinalStanding? myStanding;
    for (final s in standings) {
      if (!s.isBot && s.name == widget.name) {
        myStanding = s;
        break;
      }
    }
    if (myStanding?.placement == 1) {
      _confetti.play();
    }

    _animationController.forward(from: 0);
  }

  void _handleResumeSnapshot(Map<String, dynamic> data) {
    if (!mounted) return;

    debugPrint('Resume snapshot: $data');
  }

  void _submitAnswer(int index) {
    if (_submitted || _remainingTimeMs <= 0) {
      return;
    }

    setState(() {
      _submitted = true;
      _selectedIndex = index;
    });

    _socket.submitAnswer(index);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();

    _socket.off('question');
    _socket.off('round_result');
    _socket.off('match_over');
    _socket.off('resume_snapshot');

    _socket.disconnect();

    _animationController.dispose();
    _confetti.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    final matchFinished = _standings.isNotEmpty;

    return Scaffold(
      appBar: const AppHeader(title: 'Multiplayer'),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          _connecting
              ? const LoadingView(
                  message: 'Connecting to match…',
                  subtitle: 'Finding you an opponent.',
                  icon: Icons.wifi_tethering_rounded,
                )
              : matchFinished
                  ? _buildFinishedView(context)
                  : question == null
                      ? const LoadingView(
                          message: 'Waiting for a question…',
                          subtitle: 'The round starts automatically.',
                          icon: Icons.quiz_rounded,
                        )
                      : _buildQuestionView(context, question),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 28,
            gravity: 0.3,
            shouldLoop: false,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView(BuildContext context, MatchQuestion question) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? 0.0
            : (constraints.maxWidth >= 600 ? 24.0 : 16.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 20, horizontalPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question $_questionNumber',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (_combo >= 2) _ComboBadge(combo: _combo),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CountdownTimer(
                    remainingTime: _remainingTimeMs,
                    totalTime: question.timeMs,
                  ),
                  const SizedBox(height: 20),
                  QuestionCard(
                    question: question.promptFor(widget.lang),
                    options: question.optionsFor(widget.lang),
                    onOptionSelected: _submitted ? null : _submitAnswer,
                    selectedIndex: _selectedIndex,
                    correctIndex: _roundResult?.correctIndex,
                  ),
                  if (_roundResult != null) ...[
                    const SizedBox(height: 16),
                    _RoundResultBanner(
                      correct: _selectedIndex != null &&
                          _selectedIndex == _roundResult!.correctIndex,
                      answered: _selectedIndex != null,
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

  Widget _buildFinishedView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? 0.0
            : (constraints.maxWidth >= 600 ? 24.0 : 16.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 24, horizontalPadding, 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildResults(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults(BuildContext context) {
    FinalStanding? myStanding;

    for (final standing in _standings) {
      if (standing.name == widget.name) {
        myStanding = standing;
        break;
      }
    }

    final won = myStanding?.placement == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                won ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 56,
                color: won ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                myStanding == null
                    ? 'Match complete'
                    : (won
                        ? 'You won!'
                        : 'You placed #${myStanding.placement}'),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Final standings',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Leaderboard(
          standings: _standings,
          highlightName: widget.name,
        ),
        const SizedBox(height: 20),
        if (myStanding != null)
          RewardCard(
            xpEarned: myStanding.xpEarned ?? 0,
            streakDays: myStanding.streakDays ?? 0,
            totalXp: myStanding.totalXp,
            questsCompleted: myStanding.questsCompleted,
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            'x$combo combo',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoundResultBanner extends StatelessWidget {
  const _RoundResultBanner({required this.correct, required this.answered});

  final bool correct;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final ok = answered && correct;
    final color = !answered ? Colors.grey : (ok ? Colors.green : Colors.red);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            !answered
                ? Icons.timer_off
                : (ok ? Icons.check_circle : Icons.cancel),
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            !answered ? 'No answer submitted' : (ok ? 'Correct!' : 'Not quite'),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
