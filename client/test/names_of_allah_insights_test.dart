import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/names_of_allah.dart';
import 'package:islamic_game/utils/names_of_allah_insights.dart';

void main() {
  group('kNameInsights', () {
    test('has exactly one entry per name in kNamesOfAllah, no more, no less', () {
      final entryWords = kNamesOfAllah.map((e) => e.word).toSet();
      final insightWords = kNameInsights.keys.toSet();

      final missing = entryWords.difference(insightWords);
      expect(missing, isEmpty,
          reason: 'these names have no rich insight for the results screen: $missing');

      final extra = insightWords.difference(entryWords);
      expect(extra, isEmpty,
          reason: 'these insight keys do not match any real name (stale/typo?): $extra');
    });

    test('every insight reads as a genuine multi-sentence reflection, not a one-liner', () {
      for (final entry in kNameInsights.entries) {
        final sentenceCount = RegExp(r'[.!?]').allMatches(entry.value).length;
        expect(sentenceCount, greaterThanOrEqualTo(3),
            reason: '${entry.key}\'s insight reads too short (${entry.value.length} chars, '
                '$sentenceCount sentence-ending marks) for the "genuine depth" this screen promises');
        expect(entry.value.length, greaterThan(200),
            reason: '${entry.key}\'s insight is too short to be a real 3-4 line reflection');
      }
    });
  });
}
