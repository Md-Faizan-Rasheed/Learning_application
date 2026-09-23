import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/situation_data.dart';

class SituationSearchResult {
  const SituationSearchResult(this.category, this.situation);
  final Category category;
  final Situation situation;
}

/// Flat, filterable list of every situation across every category — the
/// "bypass the tree entirely" path from the screen's search icon.
Future<SituationSearchResult?> showSituationSearchSheet(
  BuildContext context, {
  required List<Category> categories,
}) {
  return showModalBottomSheet<SituationSearchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SearchSheet(categories: categories),
  );
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.categories});
  final List<Category> categories;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SituationSearchResult> get _results {
    final q = _query.trim().toLowerCase();
    final all = [
      for (final c in widget.categories)
        for (final s in c.situations) SituationSearchResult(c, s),
    ];
    if (q.isEmpty) return all;
    return all.where((r) {
      if (r.situation.label.toLowerCase().contains(q)) return true;
      return r.situation.keywords.any((k) => k.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final results = _results;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: t.fmaSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(t.fmaSearchNoResults,
                            style: TextStyle(color: colors.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          return ListTile(
                            title: Text(r.situation.label),
                            subtitle: Text(r.category.label),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
