import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/names_on_water_progress.dart';
import '../utils/name_chapters.dart';

/// Result of [showNamesOfAllahModePicker]: `chapterIndex == null` means
/// "Continue My Journey" (today's exact sequential auto-progress,
/// untouched); otherwise it's the chosen chapter's 0-based index.
class NamesOfAllahModeResult {
  const NamesOfAllahModeResult.continueJourney() : chapterIndex = null;
  const NamesOfAllahModeResult.chapter(int index) : chapterIndex = index;

  final int? chapterIndex;
}

/// Bottom sheet offering "Continue My Journey" (default) or "Practice a
/// Chapter" (pick a fixed 9-name range) — modeled on
/// `word_search_difficulty_sheet.dart`'s sheet chrome. Returns null if
/// dismissed without a choice.
Future<NamesOfAllahModeResult?> showNamesOfAllahModePicker(
    BuildContext context) {
  return showModalBottomSheet<NamesOfAllahModeResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ModeSheet(),
  );
}

class _ModeSheet extends StatefulWidget {
  const _ModeSheet();

  @override
  State<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends State<_ModeSheet> {
  bool _showingChapters = false;
  late final Future<Set<int>> _completedChapters;

  @override
  void initState() {
    super.initState();
    _completedChapters = NamesOnWaterProgress.instance.completedChapters();
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
                  _showingChapters
                      ? t.namesOnWaterChapterPickerTitle
                      : t.namesOnWaterModePickerTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _showingChapters
                      ? t.namesOnWaterChapterPickerSubtitle
                      : t.namesOnWaterModePickerSubtitle,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 22),
                if (_showingChapters) _buildChapterGrid(t) else _buildModeChoice(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChoice(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeCard(
          title: t.namesOnWaterContinueTitle,
          subtitle: t.namesOnWaterContinueSubtitle,
          icon: Icons.play_circle_fill_rounded,
          onTap: () => Navigator.pop(
              context, const NamesOfAllahModeResult.continueJourney()),
        ),
        const SizedBox(height: 14),
        _ModeCard(
          title: t.namesOnWaterChapterModeTitle,
          subtitle: t.namesOnWaterChapterModeSubtitle,
          icon: Icons.grid_view_rounded,
          onTap: () => setState(() => _showingChapters = true),
        ),
      ],
    );
  }

  Widget _buildChapterGrid(AppLocalizations t) {
    return FutureBuilder<Set<int>>(
      future: _completedChapters,
      builder: (context, snapshot) {
        final completed = snapshot.data ?? const {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kNameChapters.length; i++) ...[
              _ChapterCard(
                chapter: kNameChapters[i],
                completed: completed.contains(i),
                onTap: () => Navigator.pop(
                    context, NamesOfAllahModeResult.chapter(i)),
              ),
              if (i != kNameChapters.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
              Icon(widget.icon, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5)),
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

class _ChapterCard extends StatefulWidget {
  const _ChapterCard({
    required this.chapter,
    required this.completed,
    required this.onTap,
  });

  final NameChapter chapter;
  final bool completed;
  final VoidCallback onTap;

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final chapter = widget.chapter;
    final preview =
        '${chapter.names.first.displayName} → ${chapter.names.last.displayName}';

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.completed
                ? Colors.green.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.completed ? Colors.green : colors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.namesOnWaterChapterLabel(chapter.index + 1),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (widget.completed)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20)
              else
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
