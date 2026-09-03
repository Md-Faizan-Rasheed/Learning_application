import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

class TeacherClass {
  TeacherClass({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.studentCount,
  });

  final String id;
  final String name;
  final String joinCode;
  final int studentCount;

  factory TeacherClass.fromJson(Map<String, dynamic> j) => TeacherClass(
        id: j['id'] as String,
        name: j['name'] as String,
        joinCode: j['join_code'] as String,
        studentCount: j['student_count'] as int? ?? 0,
      );
}

class ClassStudent {
  ClassStudent({required this.studentId, required this.displayName});
  final String studentId;
  final String displayName;

  factory ClassStudent.fromJson(Map<String, dynamic> j) => ClassStudent(
        studentId: j['student_id'] as String,
        displayName: j['display_name'] as String,
      );
}

class TeacherClassDetail {
  TeacherClassDetail({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.students,
  });

  final String id;
  final String name;
  final String joinCode;
  final List<ClassStudent> students;

  factory TeacherClassDetail.fromJson(Map<String, dynamic> j) => TeacherClassDetail(
        id: j['id'] as String,
        name: j['name'] as String,
        joinCode: j['join_code'] as String,
        students: ((j['students'] as List?) ?? const [])
            .map((e) => ClassStudent.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// A question as seen by a teacher building a quiz — unlike ServedQuestion,
/// the correct answer IS included since the caller is authoring/picking it.
class TeacherQuestion {
  TeacherQuestion({
    required this.id,
    required this.categoryId,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final Map<String, dynamic> prompt;
  final Map<String, dynamic> options;
  final int correctIndex;

  String promptFor(String lang) =>
      (prompt[lang] ?? prompt['en'] ?? '') as String;

  factory TeacherQuestion.fromJson(Map<String, dynamic> j) => TeacherQuestion(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        difficulty: j['difficulty'] as String,
        prompt: (j['prompt'] as Map).cast<String, dynamic>(),
        options: (j['options'] as Map).cast<String, dynamic>(),
        correctIndex: j['correct_index'] as int,
      );
}

class AiImportedQuestion {
  AiImportedQuestion({required this.question, this.note});
  final TeacherQuestion question;
  final String? note;

  factory AiImportedQuestion.fromJson(Map<String, dynamic> j) => AiImportedQuestion(
        question: TeacherQuestion.fromJson(j),
        note: j['note'] as String?,
      );
}

class TeacherQuiz {
  TeacherQuiz({
    required this.id,
    required this.classId,
    required this.title,
    required this.timeLimitMs,
    required this.status,
    required this.questionCount,
  });

  final String id;
  final String classId;
  final String title;
  final int timeLimitMs;
  final String status;
  final int questionCount;

  factory TeacherQuiz.fromJson(Map<String, dynamic> j) => TeacherQuiz(
        id: j['id'] as String,
        classId: j['class_id'] as String,
        title: j['title'] as String,
        timeLimitMs: j['time_limit_ms'] as int,
        status: j['status'] as String,
        questionCount: j['question_count'] as int? ?? 0,
      );
}

class QuizStudentResult {
  QuizStudentResult({
    required this.studentId,
    required this.displayName,
    required this.status,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
  });

  final String studentId;
  final String displayName;
  final String status;
  final int? score;
  final int? correctCount;
  final int? totalQuestions;

  factory QuizStudentResult.fromJson(Map<String, dynamic> j) => QuizStudentResult(
        studentId: j['student_id'] as String,
        displayName: j['display_name'] as String,
        status: j['status'] as String,
        score: j['score'] as int?,
        correctCount: j['correct_count'] as int?,
        totalQuestions: j['total_questions'] as int?,
      );
}

class QuizResults {
  QuizResults({
    required this.quiz,
    required this.students,
    required this.averageScore,
    required this.completionRate,
  });

  final TeacherQuiz quiz;
  final List<QuizStudentResult> students;
  final double? averageScore;
  final double completionRate;

  factory QuizResults.fromJson(Map<String, dynamic> j) => QuizResults(
        quiz: TeacherQuiz.fromJson((j['quiz'] as Map).cast<String, dynamic>()),
        students: (j['students'] as List)
            .map((e) => QuizStudentResult.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        averageScore: (j['average_score'] as num?)?.toDouble(),
        completionRate: (j['completion_rate'] as num).toDouble(),
      );
}

class Category {
  Category({required this.id, required this.slug, required this.displayName});
  final String id;
  final String slug;
  final String displayName;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        slug: j['slug'] as String,
        displayName: j['display_name'] as String,
      );
}

class TeacherApi {
  TeacherApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<TeacherClass> createClass(String token, String name) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/teacher/classes'),
          headers: _headers(token),
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create class (${res.statusCode}).'));
    }
    return TeacherClass.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<TeacherClass>> listClasses(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/classes'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load classes (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => TeacherClass.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<TeacherClassDetail> getClass(String token, String classId) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/classes/$classId'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load class (${res.statusCode}).'));
    }
    return TeacherClassDetail.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<Category>> listCategories(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/categories'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load categories (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TeacherQuestion>> listBankQuestions(
    String token, {
    String? categoryId,
    String? difficulty,
  }) async {
    final params = <String, String>{
      if (categoryId != null) 'category_id': categoryId,
      if (difficulty != null) 'difficulty': difficulty,
    };
    final uri = Uri.parse('$kApiBaseUrl/teacher/bank-questions')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load question bank (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => TeacherQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TeacherQuestion>> listMyQuestions(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/questions'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load your questions (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => TeacherQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Single-language, Google-Forms-style creation: one prompt string, a
  /// plain list of option strings, and the index of the correct one. The
  /// server stores this same text under every app language so it displays
  /// as-is regardless of which language a student's app is set to.
  Future<TeacherQuestion> createQuestion(
    String token, {
    required String categoryId,
    required String prompt,
    required List<String> options,
    required int correctIndex,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/teacher/questions'),
          headers: _headers(token),
          body: jsonEncode({
            'category_id': categoryId,
            'prompt': prompt,
            'options': options,
            'correct_index': correctIndex,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create question (${res.statusCode}).'));
    }
    return TeacherQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<AiImportedQuestion>> aiImportQuestions(
    String token, {
    required String categoryId,
    required String text,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/teacher/questions/ai-import'),
          headers: _headers(token),
          body: jsonEncode({'category_id': categoryId, 'text': text}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not import questions (${res.statusCode}).'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['questions'] as List)
        .map((e) => AiImportedQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<TeacherQuestion> confirmQuestion(String token, String questionId) async {
    final res = await _client
        .post(Uri.parse('$kApiBaseUrl/teacher/questions/$questionId/confirm'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not confirm question (${res.statusCode}).'));
    }
    return TeacherQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<TeacherQuiz> createQuiz(
    String token, {
    required String title,
    required String classId,
    required int timeLimitMs,
    required List<String> questionIds,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/teacher/quizzes'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            'class_id': classId,
            'time_limit_ms': timeLimitMs,
            'question_ids': questionIds,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create quiz (${res.statusCode}).'));
    }
    return TeacherQuiz.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<TeacherQuiz> publishQuiz(String token, String quizId) async {
    final res = await _client
        .post(Uri.parse('$kApiBaseUrl/teacher/quizzes/$quizId/publish'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not publish quiz (${res.statusCode}).'));
    }
    return TeacherQuiz.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<TeacherQuiz>> listQuizzes(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/quizzes'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load quizzes (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => TeacherQuiz.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<QuizResults> getQuizResults(String token, String quizId) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/teacher/quizzes/$quizId/results'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load results (${res.statusCode}).'));
    }
    return QuizResults.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
