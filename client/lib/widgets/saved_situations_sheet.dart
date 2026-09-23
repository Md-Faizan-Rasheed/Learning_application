import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/ayah_bookmarks.dart';
import '../utils/situation_data.dart';

class SavedSituationResult {
  const SavedSituationResult(this.category, this.situation, this.refIndex);
  final Category category;
  final Situation situation;
  final int refIndex;
}

/// Lists every bookmarked reference, newest first, resolved back against
/// the live [categories] (so a rename/reorder of the source data can't
/// leave a saved entry pointing at something that no longer exists).
Future<SavedSituationResult?> showSavedSituationsSheet(
  BuildContext context, {
  required List<Category> categories,
}) {
  return showModalBottomSheet<SavedSituationResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SavedSheet(categories: categories),
  );
}

class _SavedSheet extends StatefulWidget {
  const _SavedSheet({required this.categories});
  final List<Category> categories;

  @override
  State<_SavedSheet> createState() => _SavedSheetState();
}

class _SavedSheetState extends State<_SavedSheet> {
  late Future<List<SavedReference>> _saved;

  @override
  void initState() {
    super.initState();
    _saved = AyahBookmarks.instance.all();
  }

  SavedSituationResult? _resolve(SavedReference saved) {
    for (final category in widget.categories) {
      if (category.id != saved.categoryId) continue;
      for (final situation in category.situations) {
        if (situation.id != saved.situationId) continue;
        return SavedSituationResult(category, situation, saved.refIndex);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<SavedReference>>(
          future: _saved,
          builder: (context, snapshot) {
            final saved = snapshot.data ?? const [];
            final resolved = saved.map(_resolve).whereType<SavedSituationResult>().toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(t.fmaSavedTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: resolved.isEmpty
                      ? Center(
                          child: Text(t.fmaSavedEmpty,
                              style: TextStyle(color: colors.onSurfaceVariant)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: resolved.length,
                          itemBuilder: (context, i) {
                            final r = resolved[i];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_rounded),
                              title: Text(r.situation.label),
                              subtitle: Text(r.category.label),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).pop(r),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
