import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Selects a separate SharedPreferences key space for anonymous play and each
/// saved account. The auth session already contains the stable server user ID,
/// so progress scoping does not depend on app navigation or Home state.
class LocalProgressPreferences {
  LocalProgressPreferences._();

  static const _sessionKey = 'session';
  static const _migrationKey = 'local_progress_scope_v1_migrated';
  static const _ghostKeyPrefix = 'seerah_maze_ghost_level_';

  // Legacy keys used by local progress before account scoping was introduced.
  static const _legacyKeys = <String>{
    'word_search_stats',
    'word_search_mastery',
    'names_on_water_progress',
    'names_on_water_completed_chapters',
    'find_my_ayah_visited_situations',
    'find_my_ayah_last_checkin_date',
    'find_my_ayah_seen_explore_hint',
    'find_my_ayah_bookmarks',
    'seerah_maze_progress',
    'seerah_maze_endless_best',
    'seerah_maze_daily_progress',
  };

  // Calls can begin concurrently when multiple local features load on the
  // first launch after upgrade. Share only an active migration; retaining a
  // completed future can strand later callers in a widget-test async zone.
  static Future<void>? _migrationInFlight;

  /// Resolves a legacy feature key to its current account or anonymous key.
  /// Legacy values are copied once into the namespace active on first use and
  /// left in place as a rollback/recovery copy.
  static Future<String> keyFor(String legacyKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyKeys(prefs);
    final namespace = _namespaceFor(prefs);
    return 'local_progress.v1.$namespace.$legacyKey';
  }

  static Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationKey) == true) return;

    final inFlight = _migrationInFlight;
    if (inFlight != null) {
      await inFlight;
      if (prefs.getBool(_migrationKey) == true) return;
    }

    final done = Completer<void>();
    _migrationInFlight = done.future;
    try {
      final namespace = _namespaceFor(prefs);
      final keys = <String>{
        ..._legacyKeys,
        ...prefs.getKeys().where((key) => key.startsWith(_ghostKeyPrefix)),
      };
      for (final oldKey in keys) {
        final value = prefs.get(oldKey);
        if (value == null) continue;
        final newKey = 'local_progress.v1.$namespace.$oldKey';
        if (prefs.containsKey(newKey)) continue;
        await _copyValue(prefs, newKey, value);
      }
      await prefs.setBool(_migrationKey, true);
    } finally {
      if (identical(_migrationInFlight, done.future)) {
        _migrationInFlight = null;
      }
      done.complete();
    }
  }

  static String _namespaceFor(SharedPreferences prefs) {
    final rawSession = prefs.getString(_sessionKey);
    if (rawSession == null) return 'anonymous';
    try {
      final session = jsonDecode(rawSession) as Map<String, dynamic>;
      final userId = (session['user_id'] as String?)?.trim();
      if (userId == null || userId.isEmpty) return 'anonymous';
      return 'account.${Uri.encodeComponent(userId)}';
    } catch (_) {
      return 'anonymous';
    }
  }

  static Future<void> _copyValue(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }
}
