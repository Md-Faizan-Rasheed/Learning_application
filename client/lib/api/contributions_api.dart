import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

class PublicCategory {
  PublicCategory({required this.id, required this.slug, required this.displayName});
  final String id;
  final String slug;
  final String displayName;

  factory PublicCategory.fromJson(Map<String, dynamic> j) => PublicCategory(
        id: j['id'] as String,
        slug: j['slug'] as String,
        displayName: j['display_name'] as String,
      );
}

/// A player's own submitted question and its current review status.
class Contribution {
  Contribution({
    required this.id,
    required this.categoryId,
    required this.difficulty,
    required this.reviewState,
    required this.prompt,
  });

  final String id;
  final String categoryId;
  final String difficulty;
  final String reviewState;
  final Map<String, dynamic> prompt;

  String promptFor(String lang) => (prompt[lang] ?? prompt['en'] ?? '') as String;

  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        difficulty: j['difficulty'] as String,
        reviewState: j['review_state'] as String,
        prompt: (j['prompt'] as Map).cast<String, dynamic>(),
      );
}

class ContributionsApi {
  ContributionsApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<PublicCategory>> listCategories(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/categories'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load categories (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => PublicCategory.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Contribution> submit(
    String token, {
    required String categoryId,
    required String prompt,
    required List<String> options,
    required int correctIndex,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/contributions'),
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
      throw ApiException(describeApiError(res, 'Could not submit question (${res.statusCode}).'));
    }
    return Contribution.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<Contribution>> listMine(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/contributions/mine'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load your submissions (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => Contribution.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
