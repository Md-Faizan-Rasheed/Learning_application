import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/situation_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadSituationCategories', () {
    test('parses the bundled dataset into exactly the 5 root categories the canopy expects', () async {
      final categories = await loadSituationCategories();
      expect(categories.length, 5);
      expect(categories.map((c) => c.id).toSet().length, 5,
          reason: 'category ids must be unique — the root canopy renders one Ring 1 leaf per id');
    });

    test('every situation has a non-empty label and at least one ref', () async {
      final categories = await loadSituationCategories();
      for (final category in categories) {
        expect(category.situations, isNotEmpty);
        for (final situation in category.situations) {
          expect(situation.label.trim(), isNotEmpty);
          expect(situation.refs, isNotEmpty);
        }
      }
    });

    test('every ref is a well-formed ayah or hadith with a citation', () async {
      final categories = await loadSituationCategories();
      for (final category in categories) {
        for (final situation in category.situations) {
          for (final ref in situation.refs) {
            expect(['ayah', 'hadith'], contains(ref.type));
            expect(ref.citation.trim(), isNotEmpty);
            expect(ref.gloss.trim(), isNotEmpty);
            if (ref.isAyah) {
              expect(ref.arabic.trim(), isNotEmpty,
                  reason: 'an ayah ref should carry its Arabic text');
            }
          }
        }
      }
    });

    test('situation ids are unique across the whole dataset', () async {
      final categories = await loadSituationCategories();
      final allIds = [
        for (final c in categories) for (final s in c.situations) s.id,
      ];
      expect(allIds.toSet().length, allIds.length);
    });

    test('every situation carries at least one search keyword beyond its label', () async {
      final categories = await loadSituationCategories();
      for (final category in categories) {
        for (final situation in category.situations) {
          expect(situation.keywords, isNotEmpty,
              reason: '${category.id}/${situation.id} has no keywords — '
                  'searching by anything other than its exact label will miss it');
        }
      }
    });

    test('every situation offers both an ayah and a hadith, not just one', () async {
      final categories = await loadSituationCategories();
      for (final category in categories) {
        for (final situation in category.situations) {
          final types = situation.refs.map((r) => r.type).toSet();
          expect(types, containsAll(['ayah', 'hadith']),
              reason: '${category.id}/${situation.id} is missing an ayah or a hadith — '
                  'every state of mind should offer both, not just one type of reference');
        }
      }
    });
  });
}
