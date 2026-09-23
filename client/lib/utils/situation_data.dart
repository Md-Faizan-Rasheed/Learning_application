import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A single ayah or hadith attached to a [Situation]. [gloss] is a
/// paraphrase, not a licensed translation — see the module doc on
/// [loadSituationCategories] for why, and what has to happen before this
/// ships to real users.
class Reference {
  const Reference({
    required this.type,
    required this.arabic,
    required this.gloss,
    required this.citation,
  });

  factory Reference.fromJson(Map<String, dynamic> json) => Reference(
        type: json['type'] as String,
        arabic: json['arabic'] as String? ?? '',
        gloss: json['gloss'] as String,
        citation: json['citation'] as String,
      );

  /// "ayah" or "hadith".
  final String type;

  /// Arabic script (ayah only — empty for most hadith entries here, since
  /// their exact wording isn't confidently sourced; see the disclaimer on
  /// [loadSituationCategories]).
  final String arabic;
  final String gloss;
  final String citation;

  bool get isAyah => type == 'ayah';
}

/// One life situation/emotion under a [Category], e.g. "Losing a job".
class Situation {
  const Situation({
    required this.id,
    required this.label,
    required this.refs,
    this.keywords = const [],
  });

  factory Situation.fromJson(Map<String, dynamic> json) => Situation(
        id: json['id'] as String,
        label: json['label'] as String,
        refs: (json['refs'] as List)
            .map((r) => Reference.fromJson(r as Map<String, dynamic>))
            .toList(),
        keywords: (json['keywords'] as List?)?.map((k) => k as String).toList() ?? const [],
      );

  final String id;
  final String label;
  final List<Reference> refs;

  /// Extra plain-language terms someone might type instead of the exact
  /// [label] (e.g. "job"/"debt" for "Money troubles") — matched by
  /// `situation_search_sheet.dart` alongside the label itself. Optional so
  /// older/incomplete data doesn't break parsing.
  final List<String> keywords;
}

/// One of the tree's 5 branches (Emotions, Faith, Trials, Gratitude, Meaning).
class Category {
  const Category({
    required this.id,
    required this.label,
    required this.situations,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        label: json['label'] as String,
        situations: (json['situations'] as List)
            .map((s) => Situation.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String label;
  final List<Situation> situations;
}

/// Parses the bundled `assets/data/situations.json` into [Category] objects.
///
/// **Translation note**: every [Reference.gloss] below is a paraphrase, not
/// a licensed translation — it's safe to ship as a fallback, but the actual
/// on-screen wording should come from a translation whose rights are
/// actually held (or a free-to-use API such as quran.com's), matched to
/// each entry by its `citation`, with the translator credited somewhere in
/// the app (footer/settings). Hadith gradings/wordings here are a
/// good-faith best effort and should be spot-checked against sunnah.com
/// before shipping — not everything labeled "hadith" online is authentic.
Future<List<Category>> loadSituationCategories() async {
  final raw = await rootBundle.loadString('assets/data/situations.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['categories'] as List)
      .map((c) => Category.fromJson(c as Map<String, dynamic>))
      .toList();
}
