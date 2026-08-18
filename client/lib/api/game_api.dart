import 'dart:convert';

import 'package:http/http.dart' as http;

// Where the backend lives during local web dev.
const String kApiBaseUrl = 'http://127.0.0.1:8000';

/// A question as the client receives it — note there is NO correct answer here;
/// the server withholds it until we submit.
class ServedQuestion {
  ServedQuestion({
    required this.questionId,
    required this.matchId,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.timeMs,
  });

  final String questionId;
  final String matchId;
  final String difficulty;
  final String prompt;
  final List<String> options;
  final int timeMs;

  factory ServedQuestion.fromJson(Map<String, dynamic> j) => ServedQuestion(
        questionId: j['question_id'] as String,
        matchId: j['match_id'] as String,
        difficulty: j['difficulty'] as String,
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        timeMs: j['time_ms'] as int,
      );
}

/// The server's verdict, returned only AFTER an answer is submitted.
class AnswerResult {
  AnswerResult({
    required this.isCorrect,
    required this.correctIndex,
    required this.pointsAwarded,
    required this.correctOption,
  });

  final bool isCorrect;
  final int correctIndex;
  final int pointsAwarded;
  final String correctOption;

  factory AnswerResult.fromJson(Map<String, dynamic> j) => AnswerResult(
        isCorrect: j['is_correct'] as bool,
        correctIndex: j['correct_index'] as int,
        pointsAwarded: j['points_awarded'] as int,
        correctOption: j['correct_option'] as String,
      );
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GameApi {
  GameApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<ServedQuestion> fetchPracticeQuestion({String lang = 'en'}) async {
    final uri = Uri.parse('$kApiBaseUrl/play/practice/question?lang=$lang');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) {
      throw ApiException('No live questions yet. Add one and set it to "live".');
    }
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
    return ServedQuestion.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AnswerResult> submitAnswer({
    required String matchId,
    required String questionId,
    required int? chosenIndex,
    required int responseMs,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/play/answer');
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'match_id': matchId,
            'question_id': questionId,
            'chosen_index': chosenIndex,
            'response_ms': responseMs,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
    return AnswerResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}