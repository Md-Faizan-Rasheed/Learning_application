import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/game_api.dart' show kApiBaseUrl;

/// The signed-in user's session: the JWT plus basic identity.
class Session {
  Session({
    required this.token,
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String token;
  final String userId;
  final String displayName;
  final String role;

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['access_token'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        role: j['role'] as String,
      );

  Map<String, dynamic> toStore() => {
        'token': token,
        'user_id': userId,
        'display_name': displayName,
        'role': role,
      };

  factory Session.fromStore(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        role: j['role'] as String,
      );
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to /auth/* and persists the session token across launches.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _key = 'session';

  Session? _current;
  Session? get current => _current;
  bool get isSignedIn => _current != null;

  /// Load any stored session on app start.
  Future<Session?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      _current = Session.fromStore(jsonDecode(raw) as Map<String, dynamic>);
      return _current;
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> _persist(Session s) async {
    _current = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toStore()));
  }

  Future<void> signOut() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
    required String gender,
  }) async {
    final res = await _client.post(
      Uri.parse('$kApiBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
        'gender': gender,
      }),
    );
    if (res.statusCode == 409) {
      throw AuthException('That email is already registered.');
    }
    if (res.statusCode == 422) {
      throw AuthException('Check your details (password needs 8+ characters).');
    }
    if (res.statusCode != 201) {
      throw AuthException('Registration failed (${res.statusCode}).');
    }
    final s = Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await _persist(s);
    return s;
  }

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$kApiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 401) {
      throw AuthException('Invalid email or password.');
    }
    if (res.statusCode != 200) {
      throw AuthException('Login failed (${res.statusCode}).');
    }
    final s = Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await _persist(s);
    return s;
  }

  Future<Session> guest({
    required String displayName,
    required String gender,
  }) async {
    final res = await _client.post(
      Uri.parse('$kApiBaseUrl/auth/guest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'display_name': displayName, 'gender': gender}),
    );
    if (res.statusCode != 201) {
      throw AuthException('Could not start guest session (${res.statusCode}).');
    }
    final s = Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await _persist(s);
    return s;
  }
}