import 'package:flutter/material.dart';

import '../api/admin_api.dart' show AdminCategory;
import '../l10n/app_localizations.dart';

class CategoryOption {
  const CategoryOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.colors,
  });

  final String value;
  final String title;
  final String subtitle;
  final String iconAsset;
  final List<Color> colors;
}

/// The app's fixed set of practice categories. Single source of truth for
/// both the category-picker dialog and the home screen's "journey" stops.
List<CategoryOption> categoryOptions(AppLocalizations t) => [
      CategoryOption(
        value: 'seerah',
        title: t.catSeerahTitle,
        subtitle: t.catSeerahSubtitle,
        iconAsset: 'assets/images/seerah_icon.png',
        colors: const [Color(0xFF16A34A), Color(0xFF0D9488)],
      ),
      CategoryOption(
        value: 'arabic',
        title: t.catArabicTitle,
        subtitle: t.catArabicSubtitle,
        iconAsset: 'assets/images/arabic_icon.png',
        colors: const [Color(0xFF2563EB), Color(0xFF7C3AED)],
      ),
      CategoryOption(
        value: 'mixed',
        title: t.catMixedTitle,
        subtitle: t.catMixedSubtitle,
        iconAsset: 'assets/images/mixed_icon.png',
        colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
      ),
    ];

/// Presentation for one of the three built-in slugs (custom title/icon/
/// colors), if [slug] is one of them.
CategoryOption? _builtInOption(AppLocalizations t, String slug) {
  for (final o in categoryOptions(t)) {
    if (o.value == slug) return o;
  }
  return null;
}

/// Builds the list shown by the category picker from the backend's live,
/// active-only category list, so admin-created categories appear and
/// deactivated ones (including the two built-in "seerah"/"arabic" rows)
/// disappear. "mixed" is always offered — it means "any active category"
/// and has no row of its own in the categories table.
///
/// [backendCategories] null means the fetch failed; fall back to the
/// static built-ins rather than leaving the picker empty.
List<CategoryOption> resolveCategoryOptions(
    AppLocalizations t, List<AdminCategory>? backendCategories) {
  if (backendCategories == null) return categoryOptions(t);

  return [
    _builtInOption(t, 'mixed')!,
    for (final c in backendCategories)
      if (c.slug != 'mixed')
        _builtInOption(t, c.slug) ??
            CategoryOption(
              value: c.slug,
              title: c.displayName,
              subtitle: t.catCustomSubtitle,
              iconAsset: 'assets/images/mixed_icon.png',
              colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
  ];
}
