import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/game_api.dart' show kApiBaseUrl;

/// Fire-and-forget usage logging for the Home screen's two card scrollers
/// (Today's Journey / Quick Play) — the usage data needed before deciding
/// whether/how to unify them into one navigation surface. Never awaited by
/// callers and never throws: a dropped event is fine, a logging call
/// blocking or breaking navigation is not.
class TapThroughLogger {
  TapThroughLogger._();

  static void log({
    required String section,
    required String cardId,
    String? token,
  }) {
    unawaited(_send(section: section, cardId: cardId, token: token));
  }

  static Future<void> _send({
    required String section,
    required String cardId,
    String? token,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$kApiBaseUrl/telemetry/tap-through'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'section': section,
              'card_id': cardId,
              'client_timestamp': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort logging only — a dropped event is fine.
    }
  }
}
