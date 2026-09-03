import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

class JoinedClass {
  JoinedClass({required this.classId, required this.className});
  final String classId;
  final String className;

  factory JoinedClass.fromJson(Map<String, dynamic> j) => JoinedClass(
        classId: j['class_id'] as String,
        className: j['class_name'] as String,
      );
}

class AssignedQuiz {
  AssignedQuiz({
    required this.quizId,
    required this.title,
    required this.className,
    required this.questionCount,
    required this.attemptStatus,
    required this.score,
  });

  final String quizId;
  final String title;
  final String className;
  final int questionCount;
  final String attemptStatus; // not_started | in_progress | completed
  final int? score;

  factory AssignedQuiz.fromJson(Map<String, dynamic> j) => AssignedQuiz(
        quizId: j['quiz_id'] as String,
        title: j['title'] as String,
        className: j['class_name'] as String,
        questionCount: j['question_count'] as int? ?? 0,
        attemptStatus: j['attempt_status'] as String,
        score: j['score'] as int?,
      );
}

/// A quiz question as served to the student — the correct answer is withheld.
class ServedQuizQuestion {
  ServedQuizQuestion({
    required this.quizId,
    required this.questionId,
    required this.prompt,
    required this.options,
    required this.timeLimitMs,
    required this.questionNo,
    required this.totalQuestions,
  });

  final String quizId;
  final String questionId;
  final String prompt;
  final List<String> options;
  final int timeLimitMs;
  final int questionNo;
  final int totalQuestions;

  factory ServedQuizQuestion.fromJson(Map<String, dynamic> j) => ServedQuizQuestion(
        quizId: j['quiz_id'] as String,
        questionId: j['question_id'] as String,
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        timeLimitMs: j['time_limit_ms'] as int,
        questionNo: j['question_no'] as int,
        totalQuestions: j['total_questions'] as int,
      );
}

class QuizAnswerResult {
  QuizAnswerResult({
    required this.isCorrect,
    required this.correctIndex,
    required this.pointsAwarded,
    required this.correctOption,
    required this.quizComplete,
  });

  final bool isCorrect;
  final int correctIndex;
  final int pointsAwarded;
  final String correctOption;
  final bool quizComplete;

  factory QuizAnswerResult.fromJson(Map<String, dynamic> j) => QuizAnswerResult(
        isCorrect: j['is_correct'] as bool,
        correctIndex: j['correct_index'] as int,
        pointsAwarded: j['points_awarded'] as int,
        correctOption: j['correct_option'] as String,
        quizComplete: j['quiz_complete'] as bool,
      );
}

class QuizResult {
  QuizResult({
    required this.quizId,
    required this.title,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
  });

  final String quizId;
  final String title;
  final int score;
  final int correctCount;
  final int totalQuestions;

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        quizId: j['quiz_id'] as String,
        title: j['title'] as String,
        score: j['score'] as int,
        correctCount: j['correct_count'] as int,
        totalQuestions: j['total_questions'] as int,
      );
}

class ClassroomApi {
  ClassroomApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<JoinedClass> joinClass(String token, String joinCode) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/classroom/join'),
          headers: _headers(token),
          body: jsonEncode({'join_code': joinCode}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) {
      throw ApiException('Invalid join code.');
    }
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not join class (${res.statusCode}).'));
    }
    return JoinedClass.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<AssignedQuiz>> listAssignedQuizzes(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/classroom/quizzes'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load quizzes (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => AssignedQuiz.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ServedQuizQuestion> startQuiz(String token, String quizId, {String lang = 'en'}) async {
    final res = await _client
        .get(
          Uri.parse('$kApiBaseUrl/classroom/quizzes/$quizId/start?lang=$lang'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 409) {
      throw ApiException('This quiz is already completed.');
    }
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not start quiz (${res.statusCode}).'));
    }
    return ServedQuizQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<QuizAnswerResult> answerQuestion(
    String token,
    String quizId, {
    required String questionId,
    required int? chosenIndex,
    required int? responseMs,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/classroom/quizzes/$quizId/answer'),
          headers: _headers(token),
          body: jsonEncode({
            'question_id': questionId,
            'chosen_index': chosenIndex,
            'response_ms': responseMs,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Server error (${res.statusCode}).'));
    }
    return QuizAnswerResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<QuizResult> getResult(String token, String quizId) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/classroom/quizzes/$quizId/result'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load result (${res.statusCode}).'));
    }
    return QuizResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
