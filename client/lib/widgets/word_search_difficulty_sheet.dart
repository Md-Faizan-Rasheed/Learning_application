import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/word_search_stats.dart';
import '../theme/app_theme.dart';
import '../utils/word_search_generator.dart';

/// Bottom sheet for choosing a Word Search topic and difficulty, modeled on
/// `category_picker_dialog.dart`'s sheet chrome. Topic and difficulty are
/// independent choices — picking a topic just changes which best-times are
/// shown against each difficulty card. Returns null if dismissed.
Future<(WordSearchCategory, WordSearchDifficulty)?> showWordSearchDifficultyPicker(
    BuildContext context) {
  return showModalBottomSheet<(WordSearchCategory, WordSearchDifficulty)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _DifficultySheet(),
  );
}

(String, IconData) _categoryLabel(AppLocalizations t, WordSearchCategory c) {
  switch (c) {
    case WordSearchCategory.prophets:
      return (t.wsCategoryProphets, Icons.groups_2_rounded);
    case WordSearchCategory.namesOfAllah:
      return (t.wsCategoryNamesOfAllah, Icons.brightness_7_rounded);
    case WordSearchCategory.hijriMonths:
      return (t.wsCategoryHijriMonths, Icons.calendar_month_rounded);
  }
}

class _DifficultySheet extends StatefulWidget {
  const _DifficultySheet();

  @override
  State<_DifficultySheet> createState() => _DifficultySheetState();
}

class _DifficultySheetState extends State<_DifficultySheet> {
  WordSearchCategory _category = WordSearchCategory.prophets;
  late Future<Map<WordSearchDifficulty, int?>> _bestTimes;

  @override
  void initState() {
    super.initState();
    _bestTimes = _loadBestTimes(_category);
  }

  Future<Map<WordSearchDifficulty, int?>> _loadBestTimes(
      WordSearchCategory category) async {
    final result = <WordSearchDifficulty, int?>{};
    for (final d in WordSearchDifficulty.values) {
      result[d] = await WordSearchStats.instance.bestSeconds(category, d);
    }
    return result;
  }

  void _selectCategory(WordSearchCategory category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _bestTimes = _loadBestTimes(category);
    });
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  (String, String) _labelsFor(AppLocalizations t, WordSearchDifficulty d) {
    switch (d) {
      case WordSearchDifficulty.easy:
        return (t.wsDifficultyEasy, t.wsDifficultyEasySubtitle);
      case WordSearchDifficulty.medium:
        return (t.wsDifficultyMedium, t.wsDifficultyMediumSubtitle);
      case WordSearchDifficulty.hard:
        return (t.wsDifficultyHard, t.wsDifficultyHardSubtitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

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
                      color: colors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  t.wsDifficultyPickerTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  t.wsDifficultyPickerSubtitle,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t.wsCategoryPickerLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in WordSearchCategory.values)
                      _CategoryChip(
                        label: _categoryLabel(t, c).$1,
                        icon: _categoryLabel(t, c).$2,
                        selected: c == _category,
                        onTap: () => _selectCategory(c),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                FutureBuilder<Map<WordSearchDifficulty, int?>>(
                  future: _bestTimes,
                  builder: (context, snapshot) {
                    final bestTimes = snapshot.data ?? const {};
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0;
                            i < WordSearchDifficulty.values.length;
                            i++) ...[
                          _DifficultyCard(
                            labels:
                                _labelsFor(t, WordSearchDifficulty.values[i]),
                            bestTimeText: bestTimes[
                                        WordSearchDifficulty.values[i]] !=
                                    null
                                ? t.wsBestTime(_formatSeconds(
                                    bestTimes[WordSearchDifficulty.values[i]]!))
                                : null,
                            onTap: () => Navigator.pop(
                                context, (_category, WordSearchDifficulty.values[i])),
                          ),
                          if (i != WordSearchDifficulty.values.length - 1)
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primary : AppPalette.cardStock,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : AppPalette.borderTaupe,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? colors.onPrimary : AppPalette.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: selected ? colors.onPrimary : AppPalette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatefulWidget {
  const _DifficultyCard({
    required this.labels,
    required this.bestTimeText,
    required this.onTap,
  });

  final (String, String) labels;
  final String? bestTimeText;
  final VoidCallback onTap;

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, subtitle) = widget.labels;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.tertiary, colors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.tertiary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5)),
                    if (widget.bestTimeText != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.bestTimeText!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
