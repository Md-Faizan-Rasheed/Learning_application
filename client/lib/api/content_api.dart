import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admin_api.dart' show AdminCategory;
import 'game_api.dart' show ApiException, describeApiError, kApiBaseUrl;

/// Read-only content endpoints for any signed-in user (not just admins) —
/// currently just the active category list, so player-facing pickers (what
/// to practice, what category to challenge a friend to) reflect whatever
/// categories admins have created and activated, instead of a fixed set
/// baked into the client.
class ContentApi {
  ContentApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<AdminCategory>> listCategories(String token) async {
    final res = await _client
        .get(
          Uri.parse('$kApiBaseUrl/categories'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(res, 'Could not load categories (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => AdminCategory.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
