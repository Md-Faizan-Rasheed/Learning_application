import 'package:flutter/material.dart';

import '../api/admin_api.dart' show AdminCategory;
import '../api/content_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'card_stock.dart';
import 'category_options.dart';

/// A gamified category-selection dialog: card-stock tiles differentiated by
/// icon and label only, not per-tile color. Fetches the live, active-only
/// category list from the backend (falling back to the static built-ins if that
/// fails) so admin-created categories appear and deactivated ones don't.
/// Returns the chosen category value, or null if dismissed.
Future<String?> showCategoryPicker(BuildContext context,
    {required String token}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryPickerSheet(token: token),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.token});
  final String token;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Future<List<AdminCategory>?> _future;

  @override
  void initState() {
    super.initState();
    _future = ContentApi()
        .listCategories(widget.token)
        .then<List<AdminCategory>?>((v) => v)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  t.catPickerTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  t.catPickerSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
                const SizedBox(height: 22),
                FutureBuilder<List<AdminCategory>?>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final options = resolveCategoryOptions(t, snapshot.data);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < options.length; i++) ...[
                          _CategoryOptionCard(
                            option: options[i],
                            onTap: () =>
                                Navigator.pop(context, options[i].value),
                          ),
                          if (i != options.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryOptionCard extends StatefulWidget {
  const _CategoryOptionCard({required this.option, required this.onTap});

  final CategoryOption option;
  final VoidCallback onTap;

  @override
  State<_CategoryOptionCard> createState() => _CategoryOptionCardState();
}

class _CategoryOptionCardState extends State<_CategoryOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: CardStock(
          padding: const EdgeInsets.all(14),
          borderRadius: 18,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.deepTealMuted,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  option.iconAsset,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.category_rounded, color: AppPalette.deepTeal),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: AppPalette.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.deepTeal),
            ],
          ),
        ),
      ),
    );
  }
}
