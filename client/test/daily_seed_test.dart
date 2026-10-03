import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/daily/daily_seed.dart';

void main() {
  group('utcDateOnly', () {
    test('strips the time of day', () {
      final result = utcDateOnly(DateTime.utc(2026, 3, 15, 23, 59, 59));

      expect(result, DateTime.utc(2026, 3, 15));
    });
  });

  group('dailySeedFor', () {
    test('is a pure, deterministic function of the date', () {
      final date = DateTime.utc(2026, 5, 1);

      expect(dailySeedFor(date), dailySeedFor(date));
    });

    test('ignores the time of day — only the calendar date matters', () {
      final morning = DateTime.utc(2026, 5, 1, 0, 1);
      final night = DateTime.utc(2026, 5, 1, 23, 58);

      expect(dailySeedFor(morning), dailySeedFor(night));
    });

    test('different days produce different seeds', () {
      final seeds = {
        for (var day = 1; day <= 28; day++) dailySeedFor(DateTime.utc(2026, 2, day)),
      };

      expect(seeds.length, 28, reason: 'every day in the sample should get a distinct seed');
    });

    test('rolling over a month/year boundary still changes the seed', () {
      final endOfYear = dailySeedFor(DateTime.utc(2026, 12, 31));
      final startOfNextYear = dailySeedFor(DateTime.utc(2027, 1, 1));

      expect(endOfYear, isNot(startOfNextYear));
    });
  });

  group('timeUntilNextDaily', () {
    test('counts down to the next UTC midnight', () {
      final now = DateTime.utc(2026, 5, 1, 20, 0, 0);

      expect(timeUntilNextDaily(now), const Duration(hours: 4));
    });

    test('is exactly 24 hours right at midnight', () {
      final midnight = DateTime.utc(2026, 5, 1);

      expect(timeUntilNextDaily(midnight), const Duration(hours: 24));
    });

    test('is a small positive duration one second before midnight', () {
      final almostMidnight = DateTime.utc(2026, 5, 1, 23, 59, 59);

      expect(timeUntilNextDaily(almostMidnight), const Duration(seconds: 1));
    });
  });
}
