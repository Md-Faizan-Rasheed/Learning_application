import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Base URL of the backend. Socket.IO connects here; the server wraps FastAPI,
/// so the default "/socket.io" path is correct.
const String kSocketUrl = 'http://127.0.0.1:8000';

class MatchPlayer {
  MatchPlayer({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.connected,
  });
  final int seat;
  final String name;
  final bool isBot;
  final bool connected;

  factory MatchPlayer.fromJson(Map<String, dynamic> j) => MatchPlayer(
        seat: j['seat'] as int,
        name: j['name'] as String,
        isBot: j['is_bot'] as bool,
        connected: (j['connected'] ?? true) as bool,
      );
}

class MatchQuestion {
  MatchQuestion({
    required this.questionId,
    required this.index,
    required this.prompt,
    required this.options,
    required this.deadlineMs,
    required this.timeMs,
  });
  final String questionId;
  final int index;
  final Map<String, dynamic> prompt;
  final Map<String, dynamic> options;
  final int deadlineMs;
  final int timeMs;

  factory MatchQuestion.fromJson(Map<String, dynamic> j) => MatchQuestion(
        questionId: j['question_id'] as String,
        index: j['index'] as int,
        prompt: (j['prompt'] as Map).cast<String, dynamic>(),
        options: (j['options'] as Map).cast<String, dynamic>(),
        deadlineMs: j['deadline_ms'] as int,
        timeMs: j['time_ms'] as int,
      );

  String promptFor(String lang) =>
      (prompt[lang] ?? prompt['en']) as String;
  List<String> optionsFor(String lang) =>
      ((options[lang] ?? options['en']) as List).cast<String>();
}

class RoundResultRow {
  RoundResultRow({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.chosenIndex,
    required this.isCorrect,
    required this.points,
    required this.total,
  });
  final int seat;
  final String name;
  final bool isBot;
  final int? chosenIndex;
  final bool isCorrect;
  final int points;
  final int total;

  factory RoundResultRow.fromJson(Map<String, dynamic> j) => RoundResultRow(
        seat: j['seat'] as int,
        name: j['name'] as String,
        isBot: j['is_bot'] as bool,
        chosenIndex: j['chosen_index'] as int?,
        isCorrect: j['is_correct'] as bool,
        points: j['points'] as int,
        total: j['total'] as int,
      );
}

class RoundResult {
  RoundResult({
    required this.correctIndex,
    required this.rows,
    required this.roundNo,
    required this.totalRounds,
    required this.isFinal,
  });
  final int correctIndex;
  final List<RoundResultRow> rows;
  final int roundNo;
  final int totalRounds;
  final bool isFinal;

  factory RoundResult.fromJson(Map<String, dynamic> j) => RoundResult(
        correctIndex: j['correct_index'] as int,
        roundNo: (j['round_no'] ?? 0) as int,
        totalRounds: (j['total_rounds'] ?? 0) as int,
        isFinal: (j['is_final'] ?? false) as bool,
        rows: (j['results'] as List)
            .map((e) => RoundResultRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class FinalStanding {
  FinalStanding({
    required this.placement,
    required this.name,
    required this.isBot,
    required this.total,
    this.xpEarned,
    this.streakDays,
  });
  final int placement;
  final String name;
  final bool isBot;
  final int total;
  final int? xpEarned;
  final int? streakDays;

  factory FinalStanding.fromJson(Map<String, dynamic> j) {
    final rewards = j['rewards'] as Map?;
    return FinalStanding(
      placement: j['placement'] as int,
      name: j['name'] as String,
      isBot: j['is_bot'] as bool,
      total: j['total'] as int,
      xpEarned: rewards?['xp_earned'] as int?,
      streakDays: rewards?['streak_days'] as int?,
    );
  }
}

/// Thin wrapper over socket_io_client exposing broadcast streams the UI listens to.
class MatchSocket {
  io.Socket? _socket;

  // Remembered across a drop so we can rejoin the same match.
  String? _matchId;
  String? _userId;

  final _connected = StreamController<bool>.broadcast();
  final _roster = StreamController<List<MatchPlayer>>.broadcast();
  final _question = StreamController<MatchQuestion>.broadcast();
  final _result = StreamController<RoundResult>.broadcast();
  final _matchOver = StreamController<List<FinalStanding>>.broadcast();
  final _resume = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connected => _connected.stream;
  Stream<List<MatchPlayer>> get roster => _roster.stream;
  Stream<MatchQuestion> get question => _question.stream;
  Stream<RoundResult> get result => _result.stream;
  Stream<List<FinalStanding>> get matchOver => _matchOver.stream;
  Stream<Map<String, dynamic>> get resume => _resume.stream;

  bool get hasMatch => _matchId != null && _userId != null;

  void connect({String? token}) {
    final builder = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect();
    if (token != null && token.isNotEmpty) {
      builder.setAuth({'token': token});
    }
    final socket = io.io(kSocketUrl, builder.build());
    _socket = socket;

    socket.onConnect((_) {
      _connected.add(true);
      // If we dropped mid-match, transparently rejoin on reconnect.
      if (_matchId != null && _userId != null) {
        socket.emitWithAck(
          'rejoin_match',
          {'match_id': _matchId, 'user_id': _userId},
          ack: (_) {},
        );
      }
    });
    socket.onDisconnect((_) => _connected.add(false));

    socket.on('roster', (data) {
      final players = ((data as Map)['players'] as List)
          .map((e) => MatchPlayer.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _roster.add(players);
    });
    socket.on('question', (data) {
      _question.add(MatchQuestion.fromJson((data as Map).cast<String, dynamic>()));
    });
    socket.on('round_result', (data) {
      _result.add(RoundResult.fromJson((data as Map).cast<String, dynamic>()));
    });
    socket.on('match_over', (data) {
      final standings = ((data as Map)['standings'] as List)
          .map((e) => FinalStanding.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _matchOver.add(standings);
    });
    socket.on('resume_snapshot', (data) {
      final map = (data as Map).cast<String, dynamic>();
      _matchId = map['match_id'] as String? ?? _matchId;
      _resume.add(map);
    });

    socket.connect();
  }

  void findMatch({
    required String name,
    String difficulty = 'easy',
    String category = 'mixed',
  }) {
    _socket?.emitWithAck(
      'find_match',
      {'name': name, 'difficulty': difficulty, 'category': category},
      ack: (resp) {
        if (resp is Map) {
          _matchId = resp['match_id'] as String? ?? _matchId;
          _userId = resp['user_id'] as String? ?? _userId;
        }
      },
    );
  }

  /// The server assigns a per-join user_id server-side; we learn ours from the
  /// roster/snapshot. For reconnect we store whatever the server tells us.
  void rememberIdentity({String? matchId, String? userId}) {
    _matchId = matchId ?? _matchId;
    _userId = userId ?? _userId;
  }

  void submitAnswer(int? chosenIndex) {
    _socket?.emitWithAck(
      'submit_answer',
      {'chosen_index': chosenIndex},
      ack: (_) {},
    );
  }

  void dispose() {
    _socket?.dispose();
    _connected.close();
    _roster.close();
    _question.close();
    _result.close();
    _matchOver.close();
  }
}