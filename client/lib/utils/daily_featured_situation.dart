import 'situation_data.dart';

/// One flattened (category, situation) pair — the shape the Check In tab's
/// "for right now" hero card and its situation grid both work with, since
/// neither cares about the tree's ring structure.
class SituationWithCategory {
  const SituationWithCategory(this.category, this.situation);
  final Category category;
  final Situation situation;
}

List<SituationWithCategory> flattenSituations(List<Category> categories) => [
      for (final category in categories)
        for (final situation in category.situations) SituationWithCategory(category, situation),
    ];

/// Picks a deterministic "featured" situation for [date] out of every
/// situation across every category — the same pick all day, a different
/// one tomorrow, no state to persist. Not a substitute for real
/// personalization; just a reason to open the tab even when nothing in
/// particular is on your mind, which is what seeds the daily check-in
/// habit the streak rewards.
SituationWithCategory featuredSituationFor(DateTime date, List<Category> categories) {
  final flat = flattenSituations(categories);
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  return flat[dayOfYear % flat.length];
}
