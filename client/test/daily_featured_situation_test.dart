import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/daily_featured_situation.dart';
import 'package:islamic_game/utils/situation_data.dart';

void main() {
  const categoryA = Category(id: 'a', label: 'A', situations: [
    Situation(id: 'a1', label: 'A1', refs: []),
    Situation(id: 'a2', label: 'A2', refs: []),
  ]);
  const categoryB = Category(id: 'b', label: 'B', situations: [
    Situation(id: 'b1', label: 'B1', refs: []),
  ]);
  final categories = [categoryA, categoryB];

  group('flattenSituations', () {
    test('flattens every situation across every category, category-major order', () {
      final flat = flattenSituations(categories);
      expect(flat.map((f) => f.situation.id).toList(), ['a1', 'a2', 'b1']);
      expect(flat[0].category.id, 'a');
      expect(flat[2].category.id, 'b');
    });
  });

  group('featuredSituationFor', () {
    test('is deterministic for a given calendar date', () {
      final date = DateTime(2026, 3, 15);
      final first = featuredSituationFor(date, categories);
      final second = featuredSituationFor(date, categories);
      expect(first.situation.id, second.situation.id);
    });

    test('always picks a situation that actually exists in the dataset', () {
      for (final date in [DateTime(2026, 1, 1), DateTime(2026, 6, 30), DateTime(2026, 12, 31)]) {
        final featured = featuredSituationFor(date, categories);
        expect(['a1', 'a2', 'b1'], contains(featured.situation.id));
      }
    });

    test('changes across enough distinct days to cycle through the whole list', () {
      final picks = <String>{};
      for (var day = 1; day <= 3; day++) {
        picks.add(featuredSituationFor(DateTime(2026, 1, day), categories).situation.id);
      }
      // 3 consecutive days over a 3-item flattened list should hit all of them.
      expect(picks.length, 3);
    });
  });
}
