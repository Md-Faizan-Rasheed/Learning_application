import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/services/names_on_water_progress.dart';
import 'package:islamic_game/utils/names_of_allah.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NamesOnWaterProgress', () {
    test('a fresh install starts the first batch at the beginning of the list', () async {
      final batch = await NamesOnWaterProgress.instance.nextBatch(random: Random(1));
      expect(batch.first.word, kNamesOfAllah.first.word);
      expect(batch.length, inInclusiveRange(5, 7));
    });

    test('advancing moves the pointer so the next batch continues where it left off', () async {
      final first = await NamesOnWaterProgress.instance.nextBatch(random: Random(1));
      await NamesOnWaterProgress.instance.advance(first.length);

      final second = await NamesOnWaterProgress.instance.nextBatch(random: Random(2));
      expect(second.first.word, kNamesOfAllah[first.length].word);
    });

    test('the pointer wraps around after the full list of 99 is cycled through', () async {
      // Advance almost to the end, then one more small batch to force a wrap.
      await NamesOnWaterProgress.instance.advance(kNamesOfAllah.length - 3);
      final batch = await NamesOnWaterProgress.instance.nextBatch(random: Random(1));

      // The batch should start 3 from the end and wrap into the beginning.
      expect(batch[0].word, kNamesOfAllah[kNamesOfAllah.length - 3].word);
      expect(batch[3].word, kNamesOfAllah[0].word);
    });

    test('an abandoned (never advanced) round does not move the pointer', () async {
      final first = await NamesOnWaterProgress.instance.nextBatch(random: Random(1));
      // No advance() call here — simulating leaving the round unfinished.
      final again = await NamesOnWaterProgress.instance.nextBatch(random: Random(1));
      expect(again.first.word, first.first.word);
    });
  });
}
