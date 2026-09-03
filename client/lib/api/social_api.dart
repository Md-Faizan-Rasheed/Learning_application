import 'dart:convert';

import 'package:http/http.dart' as http;

import 'game_api.dart' show kApiBaseUrl, ApiException, describeApiError;

class FriendRequestIn {
  FriendRequestIn(
      {required this.id, required this.toDisplayName, required this.status});
  final String id;
  final String toDisplayName;
  final String status;

  factory FriendRequestIn.fromJson(Map<String, dynamic> j) => FriendRequestIn(
        id: j['id'] as String,
        toDisplayName: j['to_display_name'] as String,
        status: j['status'] as String,
      );
}

/// An incoming friend request someone sent to me.
class IncomingRequest {
  IncomingRequest(
      {required this.id,
      required this.fromUserId,
      required this.displayName,
      required this.totalXp});
  final String id;
  final String fromUserId;
  final String displayName;
  final int totalXp;

  factory IncomingRequest.fromJson(Map<String, dynamic> j) => IncomingRequest(
        id: j['id'] as String,
        fromUserId: j['from_user_id'] as String,
        displayName: j['display_name'] as String,
        totalXp: j['total_xp'] as int,
      );
}

class Friend {
  Friend(
      {required this.id,
      required this.displayName,
      required this.totalXp,
      required this.streakDays});
  final String id;
  final String displayName;
  final int totalXp;
  final int streakDays;

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        totalXp: j['total_xp'] as int,
        streakDays: j['streak_days'] as int,
      );
}

class Challenge {
  Challenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.opponentId,
    required this.opponentName,
    required this.category,
    required this.questionCount,
    required this.challengerScore,
    required this.opponentScore,
    required this.status,
    required this.winnerId,
  });

  final String id;
  final String challengerId;
  final String challengerName;
  final String opponentId;
  final String opponentName;
  final String category;
  final int questionCount;
  final int? challengerScore;
  final int? opponentScore;
  final String status;
  final String? winnerId;

  bool isMine(String myUserId) => challengerId == myUserId;
  bool myTurnToPlay(String myUserId) =>
      isMine(myUserId) ? challengerScore == null : opponentScore == null;

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        challengerId: j['challenger_id'] as String,
        challengerName: j['challenger_name'] as String,
        opponentId: j['opponent_id'] as String,
        opponentName: j['opponent_name'] as String,
        category: j['category'] as String,
        questionCount: j['question_count'] as int,
        challengerScore: j['challenger_score'] as int?,
        opponentScore: j['opponent_score'] as int?,
        status: j['status'] as String,
        winnerId: j['winner_id'] as String?,
      );
}

class SocialApi {
  SocialApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<String> myFriendCode(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/social/me'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not load your friend code (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['friend_code']
        as String;
  }

  Future<FriendRequestIn> sendFriendRequest(
      String token, String friendCode) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/social/friends/requests'),
          headers: _headers(token),
          body: jsonEncode({'friend_code': friendCode}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(
          describeApiError(res, 'Could not send request (${res.statusCode}).'));
    }
    return FriendRequestIn.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Add someone by user id rather than friend code — e.g. an opponent you
  /// just played a multiplayer match with, who hasn't shared their code.
  Future<FriendRequestIn> sendFriendRequestByUserId(
      String token, String userId) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/social/friends/requests/direct'),
          headers: _headers(token),
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(
          describeApiError(res, 'Could not send request (${res.statusCode}).'));
    }
    return FriendRequestIn.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<IncomingRequest>> incomingRequests(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/social/friends/requests'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not load requests (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map(
            (e) => IncomingRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> respondToRequest(
      String token, String requestId, bool accept) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/social/friends/requests/$requestId/respond'),
          headers: _headers(token),
          body: jsonEncode({'accept': accept}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not respond to request (${res.statusCode}).'));
    }
  }

  Future<List<Friend>> myFriends(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/social/friends'), headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(
          describeApiError(res, 'Could not load friends (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => Friend.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> removeFriend(String token, String friendUserId) async {
    final res = await _client
        .delete(Uri.parse('$kApiBaseUrl/social/friends/$friendUserId'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 204) {
      throw ApiException(describeApiError(
          res, 'Could not remove friend (${res.statusCode}).'));
    }
  }

  Future<Challenge> createChallenge(
    String token, {
    required String opponentId,
    required String category,
    int questionCount = 8,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/social/challenges'),
          headers: _headers(token),
          body: jsonEncode({
            'opponent_id': opponentId,
            'category': category,
            'question_count': questionCount,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw ApiException(describeApiError(
          res, 'Could not create challenge (${res.statusCode}).'));
    }
    return Challenge.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<Challenge>> myChallenges(String token) async {
    final res = await _client
        .get(Uri.parse('$kApiBaseUrl/social/challenges'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not load challenges (${res.statusCode}).'));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => Challenge.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Challenge> submitChallengeScore(
      String token, String challengeId, int correctCount) async {
    final res = await _client
        .post(
          Uri.parse('$kApiBaseUrl/social/challenges/$challengeId/score'),
          headers: _headers(token),
          body: jsonEncode({'correct_count': correctCount}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException(describeApiError(
          res, 'Could not submit your score (${res.statusCode}).'));
    }
    return Challenge.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
