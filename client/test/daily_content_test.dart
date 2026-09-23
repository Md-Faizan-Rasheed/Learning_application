import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/daily_content.dart';

void main() {
  group('dailyIndexFor', () {
    test('is stable for every moment within the same calendar day', () {
      final morning = DateTime(2026, 3, 10, 0, 30);
      final night = DateTime(2026, 3, 10, 23, 45);
      expect(dailyIndexFor(12, now: morning), dailyIndexFor(12, now: night));
    });

    test('advances on the next calendar day', () {
      final today = DateTime(2026, 3, 10);
      final tomorrow = DateTime(2026, 3, 11);
      expect(dailyIndexFor(12, now: tomorrow),
          (dailyIndexFor(12, now: today) + 1) % 12);
    });

    test('wraps around once the pool length is exceeded', () {
      final jan1 = DateTime(2026, 1, 1);
      expect(dailyIndexFor(1, now: jan1), 0);
    });

    test('stays in range for every pool used on the home screen', () {
      for (final poolLength in [
        kDailyPhrases.length,
        kDailyHadiths.length,
        kDailyAyats.length,
      ]) {
        final index = dailyIndexFor(poolLength);
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(poolLength));
      }
    });
  });

  group('daily content pools', () {
    test('every entry has a non-empty English translation', () {
      for (final pool in [kDailyPhrases, kDailyHadiths, kDailyAyats]) {
        for (final entry in pool) {
          expect(entry.english.trim(), isNotEmpty);
        }
      }
    });
  });
}
