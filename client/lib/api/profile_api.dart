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
  });

  final String displayName;
  final int totalXp;
  final int streakDays;
  final List<MatchHistoryItem> recentMatches;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        displayName: j['display_name'] as String? ?? 'Player',
        totalXp: j['total_xp'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
        recentMatches: ((j['recent_matches'] as List?) ?? const [])
            .map((e) => MatchHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.placement,
    required this.displayName,
    required this.totalXp,
    required this.streakDays,
  });

  final int placement;
  final String displayName;
  final int totalXp;
  final int streakDays;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        placement: j['placement'] as int,
        displayName: j['display_name'] as String? ?? 'Player',
        totalXp: j['total_xp'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
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
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/leaderboard'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Could not load leaderboard (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['players'] as List)
        .map((e) => LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
