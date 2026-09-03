import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:islamic_game/api/game_api.dart';
import 'package:islamic_game/utils/league.dart';
import 'package:islamic_game/utils/level.dart';

void main() {
  group('levelForXp', () {
    test('starts at level 1 with zero XP', () {
      final level = levelForXp(0);
      expect(level.level, 1);
      expect(level.titleIndex, 0);
      expect(level.xpIntoLevel, 0);
      expect(level.nextLevelXp, 50);
    });

    test('sits exactly on a threshold', () {
      final level = levelForXp(150);
      expect(level.level, 3);
      expect(level.currentLevelXp, 150);
      expect(level.xpIntoLevel, 0);
    });

    test('falls between thresholds', () {
      final level = levelForXp(200);
      expect(level.level, 3);
      expect(level.currentLevelXp, 150);
      expect(level.xpIntoLevel, 50);
      expect(level.nextLevelXp, 300);
      expect(level.progress, closeTo(50 / 150, 1e-9));
    });

    test('caps at the final tier with no next level', () {
      final level = levelForXp(999999);
      expect(level.level, 10);
      expect(level.nextLevelXp, isNull);
      expect(level.progress, 1.0);
      expect(level.xpToNext, isNull);
    });
  });

  group('leagueForXp', () {
    test('starts at bronze with zero XP', () {
      final league = leagueForXp(0);
      expect(league.league, League.bronze);
      expect(league.nextThreshold, 300);
    });

    test('promotes at each threshold', () {
      expect(leagueForXp(300).league, League.silver);
      expect(leagueForXp(1000).league, League.gold);
      expect(leagueForXp(2500).league, League.diamond);
      expect(leagueForXp(6000).league, League.master);
    });

    test('caps at master with no next threshold', () {
      final league = leagueForXp(50000);
      expect(league.league, League.master);
      expect(league.nextThreshold, isNull);
      expect(league.progress, 1.0);
      expect(league.xpToNext, isNull);
    });

    test('tracks progress within the current league', () {
      final league = leagueForXp(650);
      expect(league.league, League.silver);
      expect(league.xpIntoLeague, 350);
      expect(league.xpToNext, 350);
    });
  });

  group('describeApiError', () {
    http.Response jsonResponse(Object body, {int status = 400}) =>
        http.Response(jsonEncode(body), status);

    test('extracts a plain string detail', () {
      final res = jsonResponse({'detail': 'That email is already taken.'});
      expect(describeApiError(res, 'fallback'), 'That email is already taken.');
    });

    test('formats FastAPI validation-error lists with their field path', () {
      final res = jsonResponse({
        'detail': [
          {
            'loc': ['body', 'options', 1],
            'msg': 'options must not be empty',
          },
        ],
      });
      expect(describeApiError(res, 'fallback'), 'options -> 1: options must not be empty');
    });

    test('falls back when the body has no detail field', () {
      final res = jsonResponse({'message': 'unrelated shape'});
      expect(describeApiError(res, 'fallback'), 'fallback');
    });

    test('falls back when the body is not JSON', () {
      final res = http.Response('not json at all', 500);
      expect(describeApiError(res, 'fallback'), 'fallback');
    });
  });
}
