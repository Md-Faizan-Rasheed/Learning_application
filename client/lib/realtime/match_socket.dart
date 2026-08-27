import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart';

class MatchSocket {
  Socket? _socket;
  String? _matchId;
  String? _userId;

  Socket? get socket => _socket;
  String? get matchId => _matchId;
  String? get userId => _userId;

  Future<bool> connect({String? token}) async {
    try {
      final completer = Completer<bool>();

      _socket = io(
        'http://127.0.0.1:8000',
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

class RoundResult {
  RoundResult({
    required this.roundNo,
    required this.correctIndex,
  });

  final int roundNo;
  final int correctIndex;

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    return RoundResult(
      roundNo: json['round_no'] as int? ?? json['round'] as int? ?? 0,
      correctIndex: json['correct_index'] as int? ?? 0,
    );
  }
}

class FinalStanding {
  FinalStanding({
    required this.placement,
    required this.name,
    required this.isBot,
    required this.total,
    this.xpEarned,
    this.streakDays,
    this.totalXp,
    this.questsCompleted = const [],
  });

  final int placement;
  final String name;
  final bool isBot;
  final int total;
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
