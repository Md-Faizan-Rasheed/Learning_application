import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/moderation_api.dart';
import '../api/social_api.dart';
import '../l10n/app_localizations.dart';
import '../realtime/match_socket.dart';
import '../services/sound_service.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/leaderboard.dart';
import '../widgets/loading_view.dart';
import '../widgets/question_card.dart';
import '../widgets/reward_card.dart';
import 'multiplayer_choice_screen.dart';
import 'multiplayer_match_report_screen.dart';

const kQuestionTimeMs = 30000;
// Mirrors match_store.MAX_SEATS server-side — used only for the lobby's
// "N/4 joined" copy, not for any matchmaking logic (the server owns that).
const kMultiplayerMaxSeats = 4;

/// How this screen entered its match: quick-match auto-finds an opponent
/// pool; hostRoom/joinRoom form a private party room by invite code instead.
enum MultiplayerMode { quickMatch, hostRoom, joinRoom }

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({
    super.key,
    required this.lang,
    required this.name,
    this.token,
    this.category = 'mixed',
    this.mode = MultiplayerMode.quickMatch,
    this.difficulty = 'easy',
    this.maxSeats = kMultiplayerMaxSeats,
    this.roomCode,
  });

  final String lang;
  final String name;
  final String? token;
  final String category;
  final MultiplayerMode mode;
  final String difficulty;
  final int maxSeats;
  final String? roomCode; // required when mode == joinRoom

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

  List<RosterPlayer> _roster = [];
  final Set<int> _answeredSeats = {};
  int? _myPreviousRank; // 0-based index into the previous round's results
  int? _myRankShift; // positive = moved up since the previous round

  int? _mySeat;
  bool _isHost = false;
  String? _roomCode;
  int _seatCap = kMultiplayerMaxSeats;
  bool _starting = false;

  final List<RoundResult> _roundHistory = [];
  final List<MatchReportEntry> _reportEntries = [];
  _MatchHighlights? _highlights;
  final Set<String> _friendRequestSent = {}; // opponent user ids
  final Set<String> _blockedUserIds = {};

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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.mpFailedConnect),
        ),
      );

      return;
    }

    _socket.on('question', _handleQuestion);
    _socket.on('round_result', _handleRoundOver);
    _socket.on('match_over', _handleMatchOver);
    _socket.on('resume_snapshot', _handleResumeSnapshot);
    _socket.on('roster', _handleRoster);
    _socket.on('player_answered', _handlePlayerAnswered);

    switch (widget.mode) {
      case MultiplayerMode.quickMatch:
        _socket.findMatch(
          name: widget.name,
          category: widget.category,
          difficulty: widget.difficulty,
        );
        break;

      case MultiplayerMode.hostRoom:
        final ack = await _socket.createRoom(
          name: widget.name,
          category: widget.category,
          difficulty: widget.difficulty,
          maxSeats: widget.maxSeats,
        );
        if (!mounted) return;
        if (ack['ok'] != true) {
          _failAndLeave(_roomErrorMessage(ack['error'] as String?));
          return;
        }
        setState(() {
          _mySeat = ack['seat'] as int?;
          _isHost = true;
          _roomCode = ack['room_code'] as String?;
          _seatCap = ack['max_seats'] as int? ?? widget.maxSeats;
        });
        break;

      case MultiplayerMode.joinRoom:
        final ack = await _socket.joinRoom(
          name: widget.name,
          roomCode: widget.roomCode ?? '',
        );
        if (!mounted) return;
        if (ack['ok'] != true) {
          _failAndLeave(_roomErrorMessage(ack['error'] as String?));
          return;
        }
        setState(() {
          _mySeat = ack['seat'] as int?;
          _isHost = false;
          _roomCode = ack['room_code'] as String?;
        });
        break;
    }

    if (!mounted) return;
    setState(() {
      _connecting = false;
    });
  }

  String _roomErrorMessage(String? error) {
    final t = AppLocalizations.of(context)!;
    switch (error) {
      case 'room not found':
        return t.mpRoomNotFound;
      case 'room full':
        return t.mpRoomFull;
      case 'room already started':
        return t.mpRoomAlreadyStarted;
      default:
        return t.mpRoomJoinFailed;
    }
  }

  void _failAndLeave(String message) {
    setState(() => _connecting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
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
      _answeredSeats.clear();
    });

    _startCountdown(question.timeMs);
  }

  void _handleRoster(Map<String, dynamic> data) {
    if (!mounted) return;
    final roster = RosterPlayer.listFromJson(data);
    final room = RoomInfo.fromJson(data);
    final wasHost = _isHost;
    final becameHost = _mySeat != null &&
        roster.any((p) => p.seat == _mySeat && p.isHost && !wasHost);

    setState(() {
      _roster = roster;
      if (widget.mode != MultiplayerMode.quickMatch) {
        _seatCap = room.maxSeats;
        _roomCode = room.roomCode ?? _roomCode;
        if (_mySeat != null) {
          final mine = roster.where((p) => p.seat == _mySeat);
          if (mine.isNotEmpty) _isHost = mine.first.isHost;
        }
      }
    });

    if (becameHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mpYouAreHostNow)),
      );
    }
  }

  Future<void> _startRoom() async {
    setState(() => _starting = true);
    final ack = await _socket.startRoom();
    if (!mounted) return;
    setState(() => _starting = false);
    if (ack['ok'] != true) {
      final t = AppLocalizations.of(context)!;
      final message = ack['error'] == 'need at least 2 players'
          ? t.mpNeedTwoPlayers
          : t.mpRoomJoinFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _shareRoomCode() {
    final code = _roomCode;
    if (code == null) return;
    final t = AppLocalizations.of(context)!;
    Share.share(t.mpShareCodeText(code));
  }

  void _handlePlayerAnswered(Map<String, dynamic> data) {
    if (!mounted) return;
    final seat = data['seat'] as int?;
    if (seat == null) return;
    setState(() => _answeredSeats.add(seat));
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

    final myIndex =
        result.results.indexWhere((r) => !r.isBot && r.name == widget.name);
    int? rankShift;
    if (myIndex != -1) {
      if (_myPreviousRank != null) {
        rankShift = _myPreviousRank! - myIndex; // positive = moved up
      }
      _myPreviousRank = myIndex;
    }

    final currentQuestion = _question;
    setState(() {
      _roundResult = result;
      _combo = wasCorrect ? _combo + 1 : 0;
      _myRankShift = rankShift;
      _roundHistory.add(result);
      if (currentQuestion != null) {
        _reportEntries.add(MatchReportEntry(
          roundNo: result.roundNo,
          question: currentQuestion,
          correctIndex: result.correctIndex,
          myChosenIndex: myIndex != -1
              ? result.results[myIndex].chosenIndex
              : _selectedIndex,
          isCorrect:
              myIndex != -1 ? result.results[myIndex].isCorrect : wasCorrect,
        ));
      }
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
      _highlights =
          _roundHistory.length >= 2 ? _computeHighlights(_roundHistory) : null;
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

  /// Fastest correct answer, closest round, and biggest single-round rank
  /// swing — all derived purely from rounds already broadcast, nothing new
  /// fetched. Callers only invoke this with 2+ rounds, since the rank-swing
  /// comparison needs at least two.
  _MatchHighlights _computeHighlights(List<RoundResult> history) {
    String? fastestName;
    bool fastestIsBot = false;
    int? fastestMs;
    int? closestRoundNo;
    int? closestGap;

    for (final round in history) {
      for (final r in round.results) {
        if (r.isCorrect &&
            r.responseMs != null &&
            (fastestMs == null || r.responseMs! < fastestMs)) {
          fastestMs = r.responseMs;
          fastestName = r.name;
          fastestIsBot = r.isBot;
        }
      }
      if (round.results.length >= 2) {
        final gap = round.results[0].total - round.results[1].total;
        if (closestGap == null || gap < closestGap) {
          closestGap = gap;
          closestRoundNo = round.roundNo;
        }
      }
    }

    String? comebackName;
    bool comebackIsBot = false;
    int? comebackSpots;
    for (var i = 1; i < history.length; i++) {
      final prevOrder = {
        for (var idx = 0; idx < history[i - 1].results.length; idx++)
          history[i - 1].results[idx].seat: idx,
      };
      final curr = history[i].results;
      for (var idx = 0; idx < curr.length; idx++) {
        final prevIdx = prevOrder[curr[idx].seat];
        if (prevIdx == null) continue;
        final swing = prevIdx - idx; // positive = moved up
        if (swing > 0 && (comebackSpots == null || swing > comebackSpots)) {
          comebackSpots = swing;
          comebackName = curr[idx].name;
          comebackIsBot = curr[idx].isBot;
        }
      }
    }

    return _MatchHighlights(
      fastestName: fastestName,
      fastestIsBot: fastestIsBot,
      fastestMs: fastestMs,
      closestRoundNo: closestRoundNo,
      closestGap: closestGap,
      comebackName: comebackName,
      comebackIsBot: comebackIsBot,
      comebackSpots: comebackSpots,
    );
  }

  /// 1.0 at no streak, ramping up to 1.4x by a streak of 5+ — mirrors
  /// PracticeScreen's combo scaling so both quiz modes escalate the reveal
  /// the same way.
  double get _comboBoost => 1.0 + (_combo.clamp(0, 5) * 0.08);

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

  /// Human opponents (not me, not bots) with a real user id — the only ones
  /// addable as friends. Empty for guests, since the social API requires
  /// auth and a guest has no [widget.token].
  List<FinalStanding> get _opponentsToAdd {
    if (widget.token == null) return const [];
    return _standings
        .where((s) => !s.isBot && s.name != widget.name && s.userId != null)
        .toList();
  }

  Future<void> _addOpponentAsFriend(FinalStanding opponent) async {
    final token = widget.token;
    final userId = opponent.userId;
    if (token == null || userId == null) return;
    final t = AppLocalizations.of(context)!;
    try {
      await SocialApi().sendFriendRequestByUserId(token, userId);
      if (!mounted) return;
      setState(() => _friendRequestSent.add(userId));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.mpFriendRequestSent(opponent.name))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _reportOpponent(FinalStanding opponent) async {
    final token = widget.token;
    final userId = opponent.userId;
    if (token == null || userId == null) return;
    final t = AppLocalizations.of(context)!;

    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (ctx) => _ReportDialog(opponentName: opponent.name),
    );
    if (result == null || !mounted) return;
    final (reason, details) = result;

    try {
      await ModerationApi().reportUser(
        token,
        reportedUserId: userId,
        reason: reason,
        details: details,
        matchId: _socket.matchId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.mpReportSubmitted(opponent.name))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _blockOpponent(FinalStanding opponent) async {
    final token = widget.token;
    final userId = opponent.userId;
    if (token == null || userId == null) return;
    final t = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.mpBlockUserTitle),
        content: Text(t.mpBlockUserConfirm(opponent.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.authCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.mpBlockUserTitle)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ModerationApi().blockUser(token, userId);
      if (!mounted) return;
      setState(() => _blockedUserIds.add(userId));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.mpUserBlocked(opponent.name))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _playAgain() {
    final token = widget.token;
    if (widget.mode != MultiplayerMode.quickMatch && token != null) {
      // Room settings (seats, code) were a one-time choice — recreating the
      // same room silently would be surprising, so send them back to pick
      // fresh rather than reusing a stale room behind the scenes.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MultiplayerChoiceScreen(
            lang: widget.lang,
            name: widget.name,
            token: token,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MultiplayerScreen(
          lang: widget.lang,
          name: widget.name,
          token: widget.token,
          category: widget.category,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();

    _socket.off('question');
    _socket.off('round_result');
    _socket.off('match_over');
    _socket.off('resume_snapshot');
    _socket.off('roster');
    _socket.off('player_answered');

    _socket.disconnect();

    _animationController.dispose();
    _confetti.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final question = _question;
    final matchFinished = _standings.isNotEmpty;

    return Scaffold(
      appBar: AppHeader(title: t.mpTitle),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            const Positioned.fill(child: AmbientBackdrop()),
            _connecting
                ? LoadingView(
                    message: t.mpConnecting,
                    subtitle: t.mpFindingOpponent,
                    icon: Icons.wifi_tethering_rounded,
                  )
                : matchFinished
                    ? _buildFinishedView(context)
                    : question == null
                        ? _buildLobbyView(context)
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
      ),
    );
  }

  Widget _buildLobbyView(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isRoom = widget.mode != MultiplayerMode.quickMatch;

    if (_roster.isEmpty) {
      return LoadingView(
        message: t.mpWaitingQuestion,
        subtitle: isRoom ? t.mpWaitingForHost : t.mpRoundAutoStart,
        icon: Icons.quiz_rounded,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded, size: 48, color: colors.primary),
            const SizedBox(height: 12),
            if (isRoom && _roomCode != null) ...[
              _RoomCodeCard(code: _roomCode!, onShare: _shareRoomCode),
              const SizedBox(height: 16),
            ],
            Text(
              t.mpLobbyJoined(
                  _roster.length, isRoom ? _seatCap : kMultiplayerMaxSeats),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isRoom
                  ? (_isHost ? t.mpTapStartWhenReady : t.mpWaitingForHost)
                  : t.mpRoundAutoStart,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in _roster) _LobbyPlayerChip(player: p),
              ],
            ),
            if (isRoom && _isHost) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed:
                    (_roster.length >= 2 && !_starting) ? _startRoom : null,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(t.mpStartGameButton),
              ),
              if (_roster.length < 2) ...[
                const SizedBox(height: 6),
                Text(
                  t.mpNeedTwoPlayers,
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView(BuildContext context, MatchQuestion question) {
    final t = AppLocalizations.of(context)!;
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
                      Flexible(
                        child: Text(
                          t.mpQuestionNumber(_questionNumber),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_combo >= 2) ...[
                        const SizedBox(width: 8),
                        _ComboBadge(combo: _combo),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  CountdownTimer(
                    remainingTime: _remainingTimeMs,
                    totalTime: question.timeMs,
                  ),
                  if (_roundResult == null && _roster.length > 1) ...[
                    const SizedBox(height: 12),
                    _OpponentPresenceRow(
                      roster: _roster,
                      answeredSeats: _answeredSeats,
                    ),
                  ],
                  const SizedBox(height: 20),
                  QuestionCard(
                    question: question.promptFor(widget.lang),
                    options: question.optionsFor(widget.lang),
                    onOptionSelected: _submitted ? null : _submitAnswer,
                    selectedIndex: _selectedIndex,
                    correctIndex: _roundResult?.correctIndex,
                    comboBoost: _comboBoost,
                  ),
                  if (_roundResult != null) ...[
                    const SizedBox(height: 16),
                    _RoundResultBanner(
                      correct: _selectedIndex != null &&
                          _selectedIndex == _roundResult!.correctIndex,
                      answered: _selectedIndex != null,
                      rankShift: _myRankShift,
                    ),
                    if (_roundResult!.isFinal) ...[
                      // The final round's own leaderboard is about to be
                      // superseded by match_over's authoritative standings a
                      // moment later — showing it here just to have it
                      // replaced reads as a glitchy double reload, so skip
                      // straight to a "finalizing" beat instead of flashing
                      // numbers that are about to change.
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t.mpFinalizingResults,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_roundResult!.results.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        t.mpThisRoundTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _RoundStandingsList(
                        results: _roundResult!.results,
                        highlightName: widget.name,
                      ),
                    ],
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
    final t = AppLocalizations.of(context)!;
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
                    ? t.mpMatchComplete
                    : (won ? t.mpYouWon : t.mpYouPlaced(myStanding.placement)),
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
          t.mpFinalStandings,
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
        if (_highlights != null && !_highlights!.isEmpty) ...[
          const SizedBox(height: 20),
          _MatchHighlightsCard(highlights: _highlights!),
        ],
        if (_opponentsToAdd.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            t.mpAddOpponents,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final opponent in _opponentsToAdd) ...[
            _AddFriendTile(
              standing: opponent,
              sent: _friendRequestSent.contains(opponent.userId),
              blocked: _blockedUserIds.contains(opponent.userId),
              onAdd: () => _addOpponentAsFriend(opponent),
              onReport: () => _reportOpponent(opponent),
              onBlock: () => _blockOpponent(opponent),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (_reportEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MatchReportScreen(
                  lang: widget.lang,
                  entries: _reportEntries,
                ),
              ),
            ),
            icon: const Icon(Icons.fact_check_rounded),
            label: Text(t.mpViewReport),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _playAgain,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(t.mpPlayAgain),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.mpBackToHome),
        ),
      ],
    );
  }
}

class _MatchHighlights {
  const _MatchHighlights({
    this.fastestName,
    this.fastestIsBot = false,
    this.fastestMs,
    this.closestRoundNo,
    this.closestGap,
    this.comebackName,
    this.comebackIsBot = false,
    this.comebackSpots,
  });

  final String? fastestName;
  final bool fastestIsBot;
  final int? fastestMs;
  final int? closestRoundNo;
  final int? closestGap;
  final String? comebackName;
  final bool comebackIsBot;
  final int? comebackSpots;

  bool get isEmpty =>
      fastestName == null && closestRoundNo == null && comebackName == null;
}

class _MatchHighlightsCard extends StatelessWidget {
  const _MatchHighlightsCard({required this.highlights});
  final _MatchHighlights highlights;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final lines = <Widget>[];

    if (highlights.fastestName != null && highlights.fastestMs != null) {
      lines.add(_HighlightLine(
        icon: Icons.bolt_rounded,
        text: t.mpFastestAnswer(
          highlights.fastestIsBot ? t.mpBot : highlights.fastestName!,
          (highlights.fastestMs! / 1000).toStringAsFixed(1),
        ),
      ));
    }
    if (highlights.closestRoundNo != null && highlights.closestGap != null) {
      lines.add(_HighlightLine(
        icon: Icons.timer_rounded,
        text: t.mpClosestRound(
            highlights.closestRoundNo! + 1, highlights.closestGap!),
      ));
    }
    if (highlights.comebackName != null && highlights.comebackSpots != null) {
      lines.add(_HighlightLine(
        icon: Icons.trending_up_rounded,
        text: t.mpBiggestComeback(
          highlights.comebackIsBot ? t.mpBot : highlights.comebackName!,
          highlights.comebackSpots!,
        ),
      ));
    }

    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.mpHighlightsTitle,
            style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            lines[i],
          ],
        ],
      ),
    );
  }
}

class _HighlightLine extends StatelessWidget {
  const _HighlightLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

class _AddFriendTile extends StatelessWidget {
  const _AddFriendTile({
    required this.standing,
    required this.sent,
    required this.blocked,
    required this.onAdd,
    required this.onReport,
    required this.onBlock,
  });
  final FinalStanding standing;
  final bool sent;
  final bool blocked;
  final VoidCallback onAdd;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              standing.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            onPressed: sent || blocked ? null : onAdd,
            icon: Icon(
                sent ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                size: 18),
            label: Text(sent ? t.mpFriendRequestSentShort : t.friendsAddBtn),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.onSurfaceVariant),
            onSelected: (value) {
              if (value == 'report') onReport();
              if (value == 'block') onBlock();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'report',
                child: Row(children: [
                  const Icon(Icons.flag_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(t.mpReportUser),
                ]),
              ),
              PopupMenuItem(
                value: 'block',
                enabled: !blocked,
                child: Row(children: [
                  Icon(blocked ? Icons.block : Icons.block_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(blocked ? t.mpUserBlockedShort : t.mpBlockUser),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.opponentName});
  final String opponentName;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = kReportReasons.first;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _reasonLabel(AppLocalizations t, String reason) => switch (reason) {
        'inappropriate_name' => t.mpReasonInappropriateName,
        'cheating' => t.mpReasonCheating,
        'harassment' => t.mpReasonHarassment,
        'spam' => t.mpReasonSpam,
        _ => t.mpReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(t.mpReportUserTitle(widget.opponentName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: InputDecoration(
              labelText: t.mpReportReasonLabel,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              for (final reason in kReportReasons)
                DropdownMenuItem(
                    value: reason, child: Text(_reasonLabel(t, reason))),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t.mpReportDetailsLabel,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.authCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_reason, _detailsController.text.trim())),
          child: Text(t.mpReportSubmitBtn),
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
            AppLocalizations.of(context)!.mpComboX(combo),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoundResultBanner extends StatelessWidget {
  const _RoundResultBanner({
    required this.correct,
    required this.answered,
    this.rankShift,
  });

  final bool correct;
  final bool answered;
  final int? rankShift;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ok = answered && correct;
    final color = !answered ? Colors.grey : (ok ? Colors.green : Colors.red);

    return Column(
      children: [
        Container(
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
                !answered
                    ? t.mpNoAnswerSubmitted
                    : (ok ? t.correct : t.incorrect),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (rankShift != null && rankShift != 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                rankShift! > 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: rankShift! > 0 ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                rankShift! > 0
                    ? t.mpRankUp(rankShift!)
                    : t.mpRankDown(-rankShift!),
                style: TextStyle(
                  color: rankShift! > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Fills in / checks off as each seat answers, from the live `roster` +
/// `player_answered` events — a lightweight "who's still thinking" signal
/// while a question is open.
class _OpponentPresenceRow extends StatelessWidget {
  const _OpponentPresenceRow(
      {required this.roster, required this.answeredSeats});

  final List<RosterPlayer> roster;
  final Set<int> answeredSeats;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          t.mpAnsweredCount(answeredSeats.length, roster.length),
          style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: [
              for (final p in roster)
                _PresenceChip(
                    player: p, answered: answeredSeats.contains(p.seat)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.player, required this.answered});

  final RosterPlayer player;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = player.name.trim().isNotEmpty
        ? player.name.trim()[0].toUpperCase()
        : '?';
    return Tooltip(
      message: player.name,
      child: CircleAvatar(
        radius: 14,
        backgroundColor:
            answered ? colors.primary : colors.surfaceContainerHighest,
        child: answered
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(
                initial,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.code, required this.onShare});
  final String code;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.mpRoomCodeLabel,
            style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded),
                tooltip: t.mpShareCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LobbyPlayerChip extends StatelessWidget {
  const _LobbyPlayerChip({required this.player});
  final RosterPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = player.name.trim().isNotEmpty
        ? player.name.trim()[0].toUpperCase()
        : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.primary.withValues(alpha: 0.18),
          child: player.isBot
              ? Icon(Icons.smart_toy_rounded, color: colors.primary)
              : Text(
                  initial,
                  style: TextStyle(
                      color: colors.primary, fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// The already-broadcast per-player breakdown for one resolved round,
/// rendered with the same podium styling as the final standings
/// (`widgets/leaderboard.dart`) by adapting each row into a [FinalStanding].
class _RoundStandingsList extends StatelessWidget {
  const _RoundStandingsList(
      {required this.results, required this.highlightName});

  final List<PlayerRoundResult> results;
  final String highlightName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: podiumOrFlatDecoration(
              index: i,
              colors: colors,
              highlighted:
                  !results[i].isBot && results[i].name == highlightName,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: i < podiumGradients.length
                      ? podiumRankBadge(i, size: 24)
                      : Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Icon(
                  results[i].isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: results[i].isCorrect ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    results[i].isBot ? t.mpBot : results[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(t.mpPts(results[i].total),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
