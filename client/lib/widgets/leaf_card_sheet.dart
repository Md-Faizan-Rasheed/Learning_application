import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/arabic_tts_service.dart';
import '../services/ayah_bookmarks.dart';
import '../utils/situation_data.dart';
import 'status_pill.dart';

/// Opens the leaf-shaped card for [situation] (within [category]), starting
/// on [initialRefIndex]. Swiping left/right cycles through the situation's
/// other refs (ayah <-> hadith) without closing the sheet.
Future<void> showLeafCardSheet(
  BuildContext context, {
  required Category category,
  required Situation situation,
  int initialRefIndex = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _LeafCardSheet(
      category: category,
      situation: situation,
      initialRefIndex: initialRefIndex,
    ),
  );
}

class _LeafCardSheet extends StatefulWidget {
  const _LeafCardSheet({
    required this.category,
    required this.situation,
    required this.initialRefIndex,
  });

  final Category category;
  final Situation situation;
  final int initialRefIndex;

  @override
  State<_LeafCardSheet> createState() => _LeafCardSheetState();
}

class _LeafCardSheetState extends State<_LeafCardSheet> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialRefIndex.clamp(0, widget.situation.refs.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  SavedReference _savedRefFor(int index) => SavedReference(
        categoryId: widget.category.id,
        categoryLabel: widget.category.label,
        situationId: widget.situation.id,
        situationLabel: widget.situation.label,
        refIndex: index,
      );

  Future<void> _toggleSave() async {
    final nowSaved = await AyahBookmarks.instance.toggle(_savedRefFor(_index));
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(nowSaved ? t.fmaSavedToast : t.fmaUnsavedToast)),
    );
  }

  /// Up to 3 other situations from the same category, deterministic
  /// (list order, not random) so the row doesn't reshuffle every time the
  /// same card is reopened.
  List<Situation> get _siblingSuggestions => widget.category.situations
      .where((s) => s.id != widget.situation.id)
      .take(3)
      .toList();

  // Reopens the sheet fresh for [sibling] rather than mutating this one in
  // place — simplest way to reset the PageView/ref index cleanly. This
  // deliberately doesn't run through `find_my_ayah_screen.dart`'s
  // check-in/progress bookkeeping (that lives one layer up, wrapping the
  // *first* `showLeafCardSheet` call): a chip clicked from inside an
  // already-open card is a "keep reading" convenience, not a fresh
  // navigation event, so it doesn't double-count toward the daily
  // check-in gate or the discovered-verses tally.
  void _openSibling(Situation sibling) {
    final navigator = Navigator.of(context);
    navigator.pop();
    showLeafCardSheet(navigator.context, category: widget.category, situation: sibling);
  }

  void _share(Reference ref) {
    final buffer = StringBuffer();
    if (ref.arabic.isNotEmpty) buffer.writeln(ref.arabic);
    buffer.writeln(ref.gloss);
    buffer.write('— ${ref.citation}');
    Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final refs = widget.situation.refs;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A thin "stem" connecting the sheet to the tree above it.
              Container(width: 2, height: 18, color: colors.secondary),
              // Flexible (not a bare Container) so the panel below can be
              // capped by the ConstrainedBox above it and scroll internally
              // — the continuation row (see _siblingSuggestions) means this
              // no longer always fits in a fixed, non-scrolling height.
              Flexible(
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  // A stylized leaf cap: rounded top-left/bottom-right,
                  // square top-right/bottom-left — the same leaf silhouette
                  // used by LeafButton, scaled up for a full sheet.
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(48),
                    bottomRight: Radius.circular(48),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.category.label} → ${widget.situation.label}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 260,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: refs.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _ReferenceCard(ref: refs[i]),
                      ),
                    ),
                    if (refs.length > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < refs.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _index == i ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _index == i ? colors.secondary : colors.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.fmaSwipeForMore,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (refs[_index].arabic.isNotEmpty)
                          _ActionButton(
                            icon: Icons.volume_up_rounded,
                            label: t.fmaPlay,
                            onTap: () => ArabicTtsService.instance.speak(refs[_index].arabic),
                          ),
                        FutureBuilder<bool>(
                          future: AyahBookmarks.instance.isSaved(_savedRefFor(_index)),
                          builder: (context, snapshot) {
                            final saved = snapshot.data ?? false;
                            return _ActionButton(
                              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              label: t.fmaSave,
                              active: saved,
                              onTap: _toggleSave,
                            );
                          },
                        ),
                        _ActionButton(
                          icon: Icons.share_rounded,
                          label: t.fmaShare,
                          onTap: () => _share(refs[_index]),
                        ),
                      ],
                    ),
                    if (_siblingSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: colors.outlineVariant),
                      const SizedBox(height: 10),
                      Text(
                        t.fmaMoreComfortLabel,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sibling in _siblingSuggestions)
                            ActionChip(
                              label: Text(sibling.label),
                              onPressed: () => _openSibling(sibling),
                            ),
                        ],
                      ),
                    ],
                  ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.ref});
  final Reference ref;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explicit type badge — the citation format alone (e.g. "Sahih
          // al-Bukhari 1") implies ayah vs hadith but never says so
          // outright, so this makes it unambiguous at a glance.
          StatusPill(
            label: ref.isAyah ? t.fmaTypeAyah : t.fmaTypeHadith,
            tone: ref.isAyah ? StatusTone.info : StatusTone.warning,
            icon: ref.isAyah ? Icons.menu_book_rounded : Icons.format_quote_rounded,
          ),
          const SizedBox(height: 10),
          if (ref.arabic.isNotEmpty) ...[
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ref.arabic,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(ref.gloss, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 10),
          Text(
            ref.citation,
            style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? colors.secondary : colors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
