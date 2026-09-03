import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException;

class MatchHistoryItem {
  MatchHistoryItem({
    required this.difficulty,
    required this.placement,
    required this.finalScore,
  });

  final String difficulty;
  final int? placement;
  final int? finalScore;

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) => MatchHistoryItem(
        difficulty: j['difficulty'] as String? ?? 'mixed',
        placement: j['placement'] as int?,
        finalScore: j['final_score'] as int?,
      );
}

class Profile {
  Profile({
    required this.displayName,
    required this.totalXp,
    required this.streakDays,
    required this.recentMatches,
    this.approvedQuestionCount = 0,
  });

  final String displayName;
  final int totalXp;
  final int streakDays;
  final List<MatchHistoryItem> recentMatches;
  final int approvedQuestionCount;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        displayName: j['display_name'] as String? ?? 'Player',
        totalXp: j['total_xp'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
        recentMatches: ((j['recent_matches'] as List?) ?? const [])
            .map((e) =>
                MatchHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        approvedQuestionCount: j['approved_question_count'] as int? ?? 0,
      );
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.id,
    required this.placement,
    required this.displayName,
    required this.totalXp,
    required this.streakDays,
    required this.isMe,
  });

  final String id;
  final int placement;
  final String displayName;
  final int totalXp;
  final int streakDays;
  final bool isMe;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        id: j['id'] as String? ?? '',
        placement: j['placement'] as int,
        displayName: j['display_name'] as String? ?? 'Player',
        totalXp: j['total_xp'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
        isMe: j['is_me'] as bool? ?? false,
      );
}

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Profile> fetchProfile(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/profile'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Could not load profile (${res.statusCode}).');
    }
    return Profile.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/leaderboard'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Could not load leaderboard (${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['players'] as List)
        .map((e) =>
            LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<LeaderboardEntry>> fetchNearbyLeaderboard(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/leaderboard/nearby'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(
          'Could not load nearby standings (${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['players'] as List)
        .map((e) =>
            LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/leaderboard/friends'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(
          'Could not load friends leaderboard (${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['players'] as List)
        .map((e) =>
            LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
