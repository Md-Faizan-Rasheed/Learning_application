import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show describeApiError, kApiBaseUrl;

class CampaignStage {
  CampaignStage({
    required this.id,
    required this.slug,
    required this.name,
    required this.orderNo,
    required this.state,
    required this.progress,
    required this.target,
    required this.questionCount,
  });

  final String id;
  final String slug;
  final Map<String, dynamic> name; // {en, ur, ar} — already localized by the API
  final int orderNo;
  final String state; // "locked" | "current" | "completed"
  final int progress;
  final int target;
  // Live count of 'live' questions tagged to this stage's event(s) —
  // computed fresh by the server on every fetch, so it reflects admin
  // tagging changes the next time this screen loads, no caching involved.
  final int questionCount;

  bool get isLocked => state == 'locked';
  bool get isCompleted => state == 'completed';

  /// Falls back to English, then to the slug itself, if a translation is
  /// missing — campaign_stages.name currently ships with ur/ar left null
  /// until a translation pass (see 0015_add_campaign_map's seed comment).
  String nameFor(String lang) =>
      (name[lang] as String?) ?? (name['en'] as String?) ?? slug;

  factory CampaignStage.fromJson(Map<String, dynamic> j) => CampaignStage(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: (j['name'] as Map).cast<String, dynamic>(),
        orderNo: j['order_no'] as int,
        state: j['state'] as String,
        progress: j['progress'] as int,
        target: j['target'] as int,
        questionCount: j['question_count'] as int? ?? 0,
      );
}

class CampaignApi {
  CampaignApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<CampaignStage>> fetchStages(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/campaign/stages'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(
          describeApiError(res, 'Could not load the campaign map (${res.statusCode}).'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return body
        .map((e) => CampaignStage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<bool> claimStageReward(String token, String stageId) async {
    final res = await _client.post(
      Uri.parse('$kApiBaseUrl/campaign/stage/$stageId/claim'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(
          describeApiError(res, 'Could not claim the reward (${res.statusCode}).'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return body['claimed'] as bool;
  }
}
