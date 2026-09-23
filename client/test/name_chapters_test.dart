import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/name_chapters.dart';
import 'package:islamic_game/utils/names_of_allah.dart';

void main() {
  group('kNameChapters', () {
    test('splits all 99 names into 11 chapters of 9 with no gaps or overlaps',
        () {
      expect(kNameChapters.length, 11);
      for (final chapter in kNameChapters) {
        expect(chapter.names.length, 9);
        expect(chapter.endNumber - chapter.startNumber + 1, 9);
      }

      final seenWords = <String>{};
      for (var i = 0; i < kNameChapters.length; i++) {
        final chapter = kNameChapters[i];
        expect(chapter.index, i);
        expect(chapter.startNumber, i * 9 + 1);
        expect(chapter.endNumber, i * 9 + 9);
        for (final name in chapter.names) {
          expect(seenWords.add(name.word), isTrue,
              reason: '${name.word} appeared in more than one chapter');
        }
      }

      expect(seenWords.length, kNamesOfAllah.length);
      expect(kNameChapters.last.endNumber, kNamesOfAllah.length);
    });

    test('chapter names match the source list in the same order', () {
      final flattened = [for (final c in kNameChapters) ...c.names];
      expect(flattened.map((e) => e.word).toList(),
          kNamesOfAllah.map((e) => e.word).toList());
    });
  });
}
