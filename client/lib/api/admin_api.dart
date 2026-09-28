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
    required this.tagStatus,
    this.eventId,
    this.stageSlug,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final String reviewState;
  final String promptPreview;
  // Null means not tagged to a campaign event — see AdminQuestion.eventId.
  final String? eventId;
  // "untagged" | "orphaned" (tagged, but that event has no campaign stage
  // link, so it's just as invisible to campaign play as untagged) |
  // "linked" (tagged and actually reachable by a campaign stage).
  final String tagStatus;
  // The campaign stage slug this question's event currently carries a
  // movement_stage tag for — null unless tagStatus == 'linked'.
  final String? stageSlug;

  factory AdminQuestionListItem.fromJson(Map<String, dynamic> j) => AdminQuestionListItem(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        difficulty: j['difficulty'] as String,
        reviewState: j['review_state'] as String,
        promptPreview: j['prompt_preview'] as String? ?? '',
        eventId: j['event_id'] as String?,
        tagStatus: j['tag_status'] as String? ?? 'untagged',
        stageSlug: j['stage_slug'] as String?,
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
    this.eventId,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final String reviewState;
  final Map<String, String> prompt;
  final Map<String, List<String>> options;
  final int correctIndex;
  // The Seerah event (seerah_events.id) this question feeds into for
  // campaign mode — null if untagged. Only meaningful for the 'seerah'
  // category; see game/repository.py:pick_live_question.
  final String? eventId;

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
        eventId: j['event_id'] as String?,
      );
}

/// One Seerah event, for the admin question editor's event-tagging picker
/// and the campaign-content management screen.
class SeerahEvent {
  SeerahEvent({
    required this.id,
    required this.slug,
    required this.name,
    this.yearHijri,
    this.summary,
  });

  final String id;
  final String slug;
  final Map<String, dynamic> name; // {en, ur, ar}
  final int? yearHijri;
  final Map<String, dynamic>? summary; // {en, ur, ar}

  String nameFor(String lang) =>
      (name[lang] as String?) ?? (name['en'] as String?) ?? slug;

  factory SeerahEvent.fromJson(Map<String, dynamic> j) => SeerahEvent(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: (j['name'] as Map).cast<String, dynamic>(),
        yearHijri: j['year_hijri'] as int?,
        summary: (j['summary'] as Map?)?.cast<String, dynamic>(),
      );
}

/// One campaign stage, for the stage-link picker on the admin question list
/// and the campaign-content management screen.
class CampaignStageOption {
  CampaignStageOption({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.orderNo,
  });

  final String id;
  final String slug;
  final Map<String, dynamic> name; // {en, ur, ar}
  final Map<String, dynamic>? description; // {en, ur, ar}
  final int orderNo;

  String nameFor(String lang) =>
      (name[lang] as String?) ?? (name['en'] as String?) ?? slug;

  factory CampaignStageOption.fromJson(Map<String, dynamic> j) => CampaignStageOption(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: (j['name'] as Map).cast<String, dynamic>(),
        description: (j['description'] as Map?)?.cast<String, dynamic>(),
        orderNo: j['order_no'] as int,
      );
}

/// One AI-extracted question, already inserted as a public 'draft' bank
/// row — see AdminApi.aiImportQuestions.
class AdminAiImportedQuestion {
  AdminAiImportedQuestion({required this.question, this.note});

  final AdminQuestion question;
  // Set when the source text didn't explicitly mark the correct answer —
  // the extractor inferred it and flags it for a human check.
  final String? note;

  factory AdminAiImportedQuestion.fromJson(Map<String, dynamic> j) =>
      AdminAiImportedQuestion(
        question: AdminQuestion.fromJson(j),
        note: j['note'] as String?,
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
    String? tagStatus,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (categoryId != null) 'category_id': categoryId,
      if (reviewState != null) 'review_state': reviewState,
      if (search != null && search.isNotEmpty) 'search': search,
      if (tagStatus != null) 'tag_status': tagStatus,
      'limit': '$limit',
      'offset': '$offset',
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

  /// Total questions matching the current filters — list_questions itself
  /// is always capped at `limit` rows per call, so this is how the admin
  /// panel knows how many exist in total and whether another page remains.
  Future<int> countQuestions(
    String token, {
    String? categoryId,
    String? reviewState,
    String? search,
    String? tagStatus,
  }) async {
    final params = <String, String>{
      if (categoryId != null) 'category_id': categoryId,
      if (reviewState != null) 'review_state': reviewState,
      if (search != null && search.isNotEmpty) 'search': search,
      if (tagStatus != null) 'tag_status': tagStatus,
    };
    final uri = Uri.parse('$kApiBaseUrl/admin/questions/count')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not count questions (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['count'] as int;
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
    String? eventId,
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
            if (eventId != null) 'event_id': eventId,
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
    String? eventId,
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
            if (eventId != null) 'event_id': eventId,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update question (${res.statusCode}).'));
    }
    return AdminQuestion.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<SeerahEvent>> listSeerahEvents(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/admin/seerah-events'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load Seerah events (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => SeerahEvent.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<CampaignStageOption>> listCampaignStages(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/admin/campaign-stages'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load campaign stages (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => CampaignStageOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Links (or, with stageSlug null, unlinks) the Seerah event behind a
  /// tagged question to a campaign stage — turns every question tagged to
  /// that event 'orphaned' <-> 'linked' at once. See AdminQuestionListItem.tagStatus.
  Future<void> setEventStageTag(String token, String eventId, String? stageSlug) async {
    final res = await _client
        .put(
          Uri.parse('$kApiBaseUrl/admin/events/$eventId/stage-tag'),
          headers: _headers(token),
          body: jsonEncode({'stage_slug': stageSlug}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update stage link (${res.statusCode}).'));
    }
  }

  Future<SeerahEvent> createSeerahEvent(
    String token, {
    required String slug,
    required Map<String, String> name,
    int? yearHijri,
    Map<String, String>? summary,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/seerah-events'),
          headers: _headers(token),
          body: jsonEncode({
            'slug': slug,
            'name': name,
            if (yearHijri != null) 'year_hijri': yearHijri,
            if (summary != null) 'summary': summary,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create event (${res.statusCode}).'));
    }
    return SeerahEvent.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<SeerahEvent> updateSeerahEvent(
    String token,
    String eventId, {
    String? slug,
    Map<String, String>? name,
    int? yearHijri,
    Map<String, String>? summary,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$kApiBaseUrl/admin/seerah-events/$eventId'),
          headers: _headers(token),
          body: jsonEncode({
            if (slug != null) 'slug': slug,
            if (name != null) 'name': name,
            if (yearHijri != null) 'year_hijri': yearHijri,
            if (summary != null) 'summary': summary,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update event (${res.statusCode}).'));
    }
    return SeerahEvent.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteSeerahEvent(String token, String eventId) async {
    final res = await _client
        .delete(Uri.parse('$kApiBaseUrl/admin/seerah-events/$eventId'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 204) {
      throw ApiException(
        describeApiError(res, 'Could not delete event (${res.statusCode}).'),
        statusCode: res.statusCode,
      );
    }
  }

  Future<CampaignStageOption> createCampaignStage(
    String token, {
    required String slug,
    required Map<String, String> name,
    Map<String, String>? description,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/campaign-stages'),
          headers: _headers(token),
          body: jsonEncode({
            'slug': slug,
            'name': name,
            if (description != null) 'description': description,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(res, 'Could not create stage (${res.statusCode}).'));
    }
    return CampaignStageOption.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<CampaignStageOption> updateCampaignStage(
    String token,
    String stageId, {
    String? slug,
    Map<String, String>? name,
    Map<String, String>? description,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$kApiBaseUrl/admin/campaign-stages/$stageId'),
          headers: _headers(token),
          body: jsonEncode({
            if (slug != null) 'slug': slug,
            if (name != null) 'name': name,
            if (description != null) 'description': description,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not update stage (${res.statusCode}).'));
    }
    return CampaignStageOption.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteCampaignStage(String token, String stageId) async {
    final res = await _client
        .delete(Uri.parse('$kApiBaseUrl/admin/campaign-stages/$stageId'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 204) {
      throw ApiException(
        describeApiError(res, 'Could not delete stage (${res.statusCode}).'),
        statusCode: res.statusCode,
      );
    }
  }

  /// Reassigns every stage's order_no to match [stageIds]' order — must
  /// contain the full existing set of stage ids exactly once.
  Future<List<CampaignStageOption>> reorderCampaignStages(String token, List<String> stageIds) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/campaign-stages/reorder'),
          headers: _headers(token),
          body: jsonEncode({'stage_ids': stageIds}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not reorder stages (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => CampaignStageOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
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

  /// Paste any freeform text and an LLM extracts it into structured
  /// multiple-choice questions, each inserted directly as a public 'draft'
  /// bank row (see AdminAiImportedQuestion) ready for the normal
  /// draft -> reviewed -> live review pipeline.
  Future<List<AdminAiImportedQuestion>> aiImportQuestions(
    String token, {
    required String categoryId,
    required String text,
    String? eventId,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/admin/questions/ai-import'),
          headers: _headers(token),
          body: jsonEncode({
            'category_id': categoryId,
            'text': text,
            if (eventId != null) 'event_id': eventId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not import questions (${res.statusCode}).'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['questions'] as List)
        .map((e) => AdminAiImportedQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
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
