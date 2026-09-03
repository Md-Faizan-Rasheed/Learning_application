import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

class AdminCategory {
  AdminCategory({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String displayName;
  final bool isActive;

  factory AdminCategory.fromJson(Map<String, dynamic> j) => AdminCategory(
        id: j['id'] as String,
        slug: j['slug'] as String,
        displayName: j['display_name'] as String,
        isActive: j['is_active'] as bool,
      );
}

class AdminQuestionListItem {
  AdminQuestionListItem({
    required this.id,
    required this.categoryId,
    required this.difficulty,
    required this.reviewState,
    required this.promptPreview,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final String reviewState;
  final String promptPreview;

  factory AdminQuestionListItem.fromJson(Map<String, dynamic> j) => AdminQuestionListItem(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        difficulty: j['difficulty'] as String,
        reviewState: j['review_state'] as String,
        promptPreview: j['prompt_preview'] as String? ?? '',
      );
}

/// Full trilingual question as authored/edited by an admin.
class AdminQuestion {
  AdminQuestion({
    required this.id,
    required this.categoryId,
    required this.difficulty,
    required this.reviewState,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final String reviewState;
  final Map<String, String> prompt;
  final Map<String, List<String>> options;
  final int correctIndex;

  factory AdminQuestion.fromJson(Map<String, dynamic> j) => AdminQuestion(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        difficulty: j['difficulty'] as String,
        reviewState: j['review_state'] as String,
        prompt: (j['prompt'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, v as String)),
        options: (j['options'] as Map)
            .cast<String, dynamic>()
            .map((k, v) => MapEntry(k, (v as List).cast<String>())),
        correctIndex: j['correct_index'] as int,
      );
}

class BulkImportError {
  BulkImportError({required this.row, required this.message});
  final int row;
  final String message;

  factory BulkImportError.fromJson(Map<String, dynamic> j) => BulkImportError(
        row: j['row'] as int,
        message: j['message'] as String,
      );
}

class BulkImportResult {
  BulkImportResult({required this.created, required this.errors});
  final int created;
  final List<BulkImportError> errors;

  factory BulkImportResult.fromJson(Map<String, dynamic> j) => BulkImportResult(
        created: j['created'] as int,
        errors: ((j['errors'] as List?) ?? const [])
            .map((e) => BulkImportError.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class AdminApi {
  AdminApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<AdminCategory>> listCategories(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/admin/categories'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load categories (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => AdminCategory.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AdminCategory> createCategory(
    String token, {
    required String slug,
    required String displayName,
    String? description,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/categories'),
          headers: _headers(token),
          body: jsonEncode({
            'slug': slug,
            'display_name': displayName,
            if (description != null) 'description': description,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create category (${res.statusCode}).'));
    }
    return AdminCategory.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminCategory> updateCategory(
    String token,
    String categoryId, {
    String? displayName,
    String? description,
    bool? isActive,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$kApiBaseUrl/admin/categories/$categoryId'),
          headers: _headers(token),
          body: jsonEncode({
            if (displayName != null) 'display_name': displayName,
            if (description != null) 'description': description,
            if (isActive != null) 'is_active': isActive,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update category (${res.statusCode}).'));
    }
    return AdminCategory.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<AdminQuestionListItem>> listQuestions(
    String token, {
    String? categoryId,
    String? reviewState,
    String? search,
  }) async {
    final params = <String, String>{
      if (categoryId != null) 'category_id': categoryId,
      if (reviewState != null) 'review_state': reviewState,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$kApiBaseUrl/admin/questions')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load questions (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => AdminQuestionListItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AdminQuestion> getQuestion(String token, String questionId) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/admin/questions/$questionId'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load question (${res.statusCode}).'));
    }
    return AdminQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminQuestion> createQuestion(
    String token, {
    required String categoryId,
    required String difficulty,
    required Map<String, String> prompt,
    required Map<String, List<String>> options,
    required int correctIndex,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/questions'),
          headers: _headers(token),
          body: jsonEncode({
            'category_id': categoryId,
            'difficulty': difficulty,
            'prompt': prompt,
            'options': options,
            'correct_index': correctIndex,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create question (${res.statusCode}).'));
    }
    return AdminQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminQuestion> updateQuestion(
    String token,
    String questionId, {
    String? categoryId,
    String? difficulty,
    Map<String, String>? prompt,
    Map<String, List<String>>? options,
    int? correctIndex,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$kApiBaseUrl/admin/questions/$questionId'),
          headers: _headers(token),
          body: jsonEncode({
            if (categoryId != null) 'category_id': categoryId,
            if (difficulty != null) 'difficulty': difficulty,
            if (prompt != null) 'prompt': prompt,
            if (options != null) 'options': options,
            if (correctIndex != null) 'correct_index': correctIndex,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update question (${res.statusCode}).'));
    }
    return AdminQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminQuestion> reviewQuestion(String token, String questionId, String state) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/questions/$questionId/review?state=$state'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update review state (${res.statusCode}).'));
    }
    return AdminQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<BulkImportResult> bulkImportQuestions(
    String token, {
    required String format,
    required String content,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/questions/bulk-import'),
          headers: _headers(token),
          body: jsonEncode({'format': format, 'content': content}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not import questions (${res.statusCode}).'));
    }
    return BulkImportResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteQuestion(String token, String questionId) async {
    final res = await _client
        .delete(Uri.parse('$kApiBaseUrl/admin/questions/$questionId'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 204) {
      throw ApiException(
        describeApiError(res, 'Could not delete question (${res.statusCode}).'),
        statusCode: res.statusCode,
      );
    }
  }
}
