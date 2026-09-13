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

/// What completing a solo activity (currently just Word Search) earned —
/// the non-match equivalent of the "you earned…" summary a finished
/// multiplayer match produces.
class ActivityResult {
  ActivityResult({
    required this.xpEarned,
    required this.totalXp,
    required this.streakDays,
    required this.streakExtended,
  });

  final int xpEarned;
  final int totalXp;
  final int streakDays;
  final bool streakExtended;

  factory ActivityResult.fromJson(Map<String, dynamic> j) => ActivityResult(
        xpEarned: j['xp_earned'] as int? ?? 0,
        totalXp: j['total_xp'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
        streakExtended: j['streak_extended'] as bool? ?? false,
      );
}

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Reports a finished solo activity so it counts toward the real,
  /// persisted profile (XP + daily streak) — the same ledger a finished
  /// multiplayer match updates. Requires a logged-in [token]; there is no
  /// anonymous/guest path for this call (unlike the /play/* practice
  /// endpoints), since XP has to be attributed to a real account.
  Future<ActivityResult> completeActivity(
    String token, {
    required String activity,
    String? category,
    required String difficulty,
    required int wordsFound,
    required int totalWords,
    required int seconds,
    required int hintsUsed,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/me/activity/complete'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'activity': activity,
            'category': category,
            'difficulty': difficulty,
            'words_found': wordsFound,
            'total_words': totalWords,
            'seconds': seconds,
            'hints_used': hintsUsed,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Could not record activity (${res.statusCode}).');
    }
    return ActivityResult.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

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
