import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

const kReportReasons = [
  'inappropriate_name',
  'cheating',
  'harassment',
  'spam',
  'other',
];

class BlockedUser {
  BlockedUser({required this.userId, required this.displayName});
  final String userId;
  final String displayName;

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
      );
}

class AdminReport {
  AdminReport({
    required this.id,
    required this.reporterName,
    required this.reportedName,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterName;
  final String reportedName;
  final String reason;
  final String? details;
  final String status;
  final String createdAt;

  factory AdminReport.fromJson(Map<String, dynamic> j) => AdminReport(
        id: j['id'] as String,
        reporterName: j['reporter_name'] as String,
        reportedName: j['reported_name'] as String,
        reason: j['reason'] as String,
        details: j['details'] as String?,
        status: j['status'] as String,
        createdAt: j['created_at'] as String,
      );
}

class ModerationApi {
  ModerationApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> reportUser(
    String token, {
    required String reportedUserId,
    required String reason,
    String? details,
    String? matchId,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/moderation/report'),
          headers: _headers(token),
          body: jsonEncode({
            'reported_user_id': reportedUserId,
            'reason': reason,
            if (details != null && details.isNotEmpty) 'details': details,
            if (matchId != null) 'match_id': matchId,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(
          describeApiError(res, 'Could not submit report (${res.statusCode}).'));
    }
  }

  Future<void> blockUser(String token, String userId) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/moderation/block'),
          headers: _headers(token),
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(
          describeApiError(res, 'Could not block user (${res.statusCode}).'));
    }
  }

  Future<void> unblockUser(String token, String userId) async {
    final res = await _client
        .delete(Uri.parse('$kApiBaseUrl/moderation/block/$userId'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 204) {
      throw ApiException(
          describeApiError(res, 'Could not unblock user (${res.statusCode}).'));
    }
  }

  Future<List<BlockedUser>> listBlocked(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/moderation/blocked'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not load blocked users (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => BlockedUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<AdminReport>> listReports(String token,
      {String status = 'open'}) async {
    final res = await _client
        .get(
          Uri.parse('$kApiBaseUrl/admin/reports?report_status=$status'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not load reports (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => AdminReport.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setReportStatus(
      String token, String reportId, String status) async {
    final res = await _client
        .patch(
          Uri.parse('$kApiBaseUrl/admin/reports/$reportId'),
          headers: _headers(token),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not update report (${res.statusCode}).'));
    }
  }
}
