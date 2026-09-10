import 'dart:convert';

import 'package:http/http.dart' as http;

// The backend's base URL. Defaults to local dev (8000 and 8010 both ended up
// with a stuck kernel-level listening socket on this machine — netstat shows
// a PID that no longer exists in the process table, and nothing can free it
// short of a reboot — 8091 sidesteps it; if this ever gets stuck too, bump
// the port here and in your `uvicorn --port` command).
//
// For a release build pointed at a real deployed backend, override at build
// time instead of editing this default:
//   flutter build appbundle --dart-define=API_BASE_URL=https://your-backend.example.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://learning-application-re35.onrender.com',
  // defaultValue: 'http://localhost:8091',
);

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
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Pulls FastAPI's `detail` out of a non-2xx JSON body so error messages are
/// actionable (e.g. "options -> 1: options must not be empty") instead of a
/// bare status code. Falls back to [fallback] if the body isn't in that shape.
String describeApiError(http.Response res, String fallback) {
  try {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      if (d is String) return d;
      if (d is List) {
        return d.map((e) {
          if (e is Map) {
            final loc = (e['loc'] as List?)?.skip(1).join(' -> ') ?? '';
            final msg = e['msg'] ?? '';
            return loc.isEmpty ? '$msg' : '$loc: $msg';
          }
          return e.toString();
        }).join('; ');
      }
    }
  } catch (_) {
    // Body wasn't JSON, or not in FastAPI's error shape — use the fallback.
  }
  return fallback;
}

class GameApi {
  GameApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<ServedQuestion> fetchPracticeQuestion({
    String lang = 'en',
    String category = 'mixed',
  }) async {
    final catParam = category == 'mixed' ? '' : '&category=$category';
    final uri = Uri.parse(
        '$kApiBaseUrl/play/practice/question?lang=$lang$catParam');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) {
      throw ApiException('No live questions yet. Add one and set it to "live".');
    }
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
    return ServedQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
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
    return AnswerResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}