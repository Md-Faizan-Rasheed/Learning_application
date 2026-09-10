import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart';

import '../api/game_api.dart' show kApiBaseUrl;

class MatchSocket {
  Socket? _socket;
  String? _matchId;
  String? _userId;

  Socket? get socket => _socket;
  String? get matchId => _matchId;
  String? get userId => _userId;

  Future<Map<String, dynamic>> _emitWithAck(
      String event, Map<String, dynamic> data) {
    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      event,
      data,
      ack: (resp) {
        if (completer.isCompleted) return;
        if (resp is Map) {
          completer.complete(Map<String, dynamic>.from(resp));
        } else {
          completer.complete({'ok': false, 'error': 'no response'});
        }
      },
    );
    return completer.future;
  }

  Future<bool> connect({String? token}) async {
    try {
      final completer = Completer<bool>();

      _socket = io(
        kApiBaseUrl,
        OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({
              if (token != null) 'token': token,
            })
            .disableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        print('Connected to server');

        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      _socket!.onConnectError((data) {
        print('Failed to connect: $data');

        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _socket!.onDisconnect((_) {
        print('Disconnected from server');
      });

      _socket!.connect();

      return await completer.future;
    } catch (e) {
      print('Error connecting to server: $e');
      return false;
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(
    String event,
    Function(Map<String, dynamic>) handler,
  ) {
    _socket?.on(event, (data) {
      try {
        Map<String, dynamic> parsedData;

        if (data is String) {
          parsedData = Map<String, dynamic>.from(
            jsonDecode(data) as Map,
          );
        } else if (data is Map) {
          parsedData = Map<String, dynamic>.from(data);
        } else {
          print('Unexpected $event data: $data');
          return;
        }

        handler(parsedData);
      } catch (e) {
        print('Error parsing $event: $e');
      }
    });
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(
    String event,
    Map<String, dynamic> data,
  ) {
    _socket?.emit(event, data);
  }

  void findMatch({
    required String name,
    String difficulty = 'easy',
    String category = 'mixed',
  }) {
    _socket?.emitWithAck(
      'find_match',
      {
        'name': name,
        'difficulty': difficulty,
        'category': category,
      },
      ack: (resp) {
        if (resp is Map) {
          _matchId = resp['match_id'] as String? ?? _matchId;
          _userId = resp['user_id'] as String? ?? _userId;

          print('Match ID: $_matchId');
          print('User ID: $_userId');
        }
      },
    );
  }

  /// Host creates a party room. Returns the raw ack — unlike [findMatch],
  /// this can fail in a user-visible way (e.g. code generation collision),
  /// so the caller needs to see `ok`/`error`, not just the stashed ids.
  Future<Map<String, dynamic>> createRoom({
    required String name,
    String difficulty = 'easy',
    String category = 'mixed',
    required int maxSeats,
  }) async {
    final resp = await _emitWithAck('create_room', {
      'name': name,
      'difficulty': difficulty,
      'category': category,
      'max_seats': maxSeats,
    });
    if (resp['ok'] == true) {
      _matchId = resp['match_id'] as String? ?? _matchId;
      _userId = resp['user_id'] as String? ?? _userId;
    }
    return resp;
  }

  /// A friend joins a room by its invite code. Can fail (bad code, room
  /// full, room already started) — the caller must check `ok`.
  Future<Map<String, dynamic>> joinRoom({
    required String name,
    required String roomCode,
  }) async {
    final resp = await _emitWithAck('join_room', {
      'name': name,
      'room_code': roomCode,
    });
    if (resp['ok'] == true) {
      _matchId = resp['match_id'] as String? ?? _matchId;
      _userId = resp['user_id'] as String? ?? _userId;
    }
    return resp;
  }

  /// The host starts their room early (no bot backfill) — the server
  /// resolves which room from this socket's own seat, not a client-supplied
  /// match id.
  Future<Map<String, dynamic>> startRoom() => _emitWithAck('start_room', {});

  void submitAnswer(int index) {
    emit(
      'submit_answer',
      {
        'chosen_index': index,
      },
    );
  }
}

class MatchQuestion {
  MatchQuestion({
    required this.questionId,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.timeMs,
  });

  final String questionId;
  final String difficulty;
  final Map<String, String> prompt;
  final Map<String, List<String>> options;
  final int correctIndex;
  final int timeMs;

  factory MatchQuestion.fromJson(Map<String, dynamic> json) {
    return MatchQuestion(
      questionId: json['question_id'] as String? ?? json['id'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'easy',
      prompt: _parsePrompt(json['prompt']),
      options: _parseOptions(json['options']),
      correctIndex: json['correct_index'] as int? ?? 0,
      timeMs: json['time_ms'] as int? ?? 20000,
    );
  }

  String promptFor(String lang) {
    return prompt[lang] ?? prompt['en'] ?? prompt.values.firstOrNull ?? '';
  }

  List<String> optionsFor(String lang) {
    return options[lang] ?? options['en'] ?? options.values.firstOrNull ?? [];
  }

  static Map<String, String> _parsePrompt(dynamic value) {
    if (value is! Map) {
      return {};
    }

    return value.map(
      (key, value) => MapEntry(
        key.toString(),
        value.toString(),
      ),
    );
  }

  static Map<String, List<String>> _parseOptions(dynamic value) {
    if (value is! Map) {
      return {};
    }

    return value.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((item) => item.toString()).toList()
            : <String>[],
      ),
    );
  }
}

/// One player's outcome for a single resolved round — the full per-player
/// breakdown the server already sends in `round_result`, previously
/// discarded by [RoundResult.fromJson].
class PlayerRoundResult {
  PlayerRoundResult({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.chosenIndex,
    required this.isCorrect,
    required this.points,
    required this.total,
    this.responseMs,
  });

  final int seat;
  final String name;
  final bool isBot;
  final int? chosenIndex;
  final bool isCorrect;
  final int points;
  final int total;
  final int? responseMs;

  factory PlayerRoundResult.fromJson(Map<String, dynamic> json) {
    return PlayerRoundResult(
      seat: json['seat'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isBot: json['is_bot'] as bool? ?? false,
      chosenIndex: json['chosen_index'] as int?,
      isCorrect: json['is_correct'] as bool? ?? false,
      points: json['points'] as int? ?? 0,
      responseMs: json['response_ms'] as int?,
      total: json['total'] as int? ?? 0,
    );
  }
}

/// One resolved round, paired with the question it was for — built
/// client-side purely from data already broadcast during the match (each
/// `question` snapshot combined with its own `round_result`), so the
/// post-match report needs no extra fetch from the server.
class MatchReportEntry {
  MatchReportEntry({
    required this.roundNo,
    required this.question,
    required this.correctIndex,
    required this.myChosenIndex,
    required this.isCorrect,
  });

  final int roundNo;
  final MatchQuestion question;
  final int correctIndex;
  final int? myChosenIndex;
  final bool isCorrect;
}

class RoundResult {
  RoundResult({
    required this.roundNo,
    required this.correctIndex,
    required this.results,
    required this.isFinal,
  });

  final int roundNo;
  final int correctIndex;
  final List<PlayerRoundResult> results;
  final bool isFinal;

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return RoundResult(
      roundNo: json['round_no'] as int? ?? json['round'] as int? ?? 0,
      correctIndex: json['correct_index'] as int? ?? 0,
      results: rawResults is List
          ? rawResults
              .whereType<Map>()
              .map((e) =>
                  PlayerRoundResult.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      isFinal: json['is_final'] as bool? ?? false,
    );
  }
}

/// One seat's presence info — who's in the match right now, from the
/// `roster` event (broadcast on join/leave/rejoin/disconnect).
class RosterPlayer {
  RosterPlayer({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.connected,
    this.isHost = false,
  });

  final int seat;
  final String name;
  final bool isBot;
  final bool connected;
  final bool isHost;

  factory RosterPlayer.fromJson(Map<String, dynamic> json) {
    return RosterPlayer(
      seat: json['seat'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isBot: json['is_bot'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      isHost: json['is_host'] as bool? ?? false,
    );
  }

  static List<RosterPlayer> listFromJson(Map<String, dynamic> json) {
    final raw = json['players'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => RosterPlayer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// Party-room context carried on every `roster` broadcast — null/absent
/// fields mean "this is a quick-match, not a room."
class RoomInfo {
  RoomInfo({required this.maxSeats, required this.roomCode});

  final int maxSeats;
  final String? roomCode;

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
        maxSeats: json['max_seats'] as int? ?? 4,
        roomCode: json['room_code'] as String?,
      );
}

class FinalStanding {
  FinalStanding({
    required this.placement,
    required this.name,
    required this.isBot,
    required this.total,
    this.userId,
    this.xpEarned,
    this.streakDays,
    this.totalXp,
    this.questsCompleted = const [],
  });

  final int placement;
  final String name;
  final bool isBot;
  final int total;
  final String? userId;
  final int? xpEarned;
  final int? streakDays;
  final int? totalXp;
  final List<String> questsCompleted;

  factory FinalStanding.fromJson(Map<String, dynamic> json) {
    final rewards = json['rewards'] is Map
        ? Map<String, dynamic>.from(json['rewards'] as Map)
        : <String, dynamic>{};

    final quests = rewards['quests_completed'];

    return FinalStanding(
      placement: json['placement'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isBot: json['is_bot'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
      userId: json['user_id'] as String?,
      xpEarned: rewards['xp_earned'] as int?,
      streakDays: rewards['streak_days'] as int?,
      totalXp: rewards['total_xp'] as int?,
      questsCompleted: quests is List
          ? quests.map((q) {
              if (q is Map) {
                return q['description']?.toString() ?? '';
              }
              return q.toString();
            }).toList()
          : const [],
    );
  }
}
