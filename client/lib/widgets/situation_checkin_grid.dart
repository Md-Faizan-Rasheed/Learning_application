import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/daily_featured_situation.dart';
import '../utils/situation_data.dart';

/// A per-category glyph for the Check In grid's chips — purely a client-side
/// visual hint, not part of the data file, since which icon "fits" a
/// category is a UI decision, not content.
const Map<String, IconData> _kCategoryIcons = {
  'emotions': Icons.self_improvement_rounded,
  'faith': Icons.mosque_rounded,
  'trials': Icons.shield_outlined,
  'gratitude': Icons.favorite_rounded,
  'meaning': Icons.auto_awesome_rounded,
};

IconData _iconFor(String categoryId) => _kCategoryIcons[categoryId] ?? Icons.spa_rounded;

/// The Check In tab's content: a "for right now" featured card, a
/// category-filter chip row, and a wrapped grid of every situation in the
/// filtered scope. Fires [onOpen] directly — no intermediate navigation —
/// which is the whole point of this tab existing alongside the Explore
/// tree (see `find_my_ayah_screen.dart`'s module doc).
class SituationCheckInGrid extends StatefulWidget {
  const SituationCheckInGrid({
    super.key,
    required this.categories,
    required this.visitedSituationIds,
    required this.onOpen,
  });

  final List<Category> categories;
  final Set<String> visitedSituationIds;
  final void Function(Category category, Situation situation) onOpen;

  @override
  State<SituationCheckInGrid> createState() => _SituationCheckInGridState();
}

class _SituationCheckInGridState extends State<SituationCheckInGrid> {
  String? _activeCategoryId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final featured = featuredSituationFor(DateTime.now(), widget.categories);
    final visibleCategories = _activeCategoryId == null
        ? widget.categories
        : widget.categories.where((c) => c.id == _activeCategoryId).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          t.fmaCheckInPrompt,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        _FeaturedCard(
          categoryLabel: featured.category.label,
          situation: featured.situation,
          icon: _iconFor(featured.category.id),
          featuredLabel: t.fmaFeaturedLabel,
          onTap: () => widget.onOpen(featured.category, featured.situation),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryFilterChip(
                label: t.fmaCategoryFilterAll,
                selected: _activeCategoryId == null,
                onTap: () => setState(() => _activeCategoryId = null),
              ),
              for (final category in widget.categories) ...[
                const SizedBox(width: 8),
                _CategoryFilterChip(
                  label: category.label,
                  selected: _activeCategoryId == category.id,
                  onTap: () => setState(() => _activeCategoryId = category.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in visibleCategories)
              for (final situation in category.situations)
                _SituationChip(
                  key: ValueKey('checkin_chip_${situation.id}'),
                  label: situation.label,
                  icon: _iconFor(category.id),
                  visited: widget.visitedSituationIds.contains(situation.id),
                  visitedTooltip: t.fmaAlreadyVisited,
                  onTap: () => widget.onOpen(category, situation),
                ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.categoryLabel,
    required this.situation,
    required this.icon,
    required this.featuredLabel,
    required this.onTap,
  });

  final String categoryLabel;
  final Situation situation;
  final IconData icon;
  final String featuredLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppPalette.deepTeal, Color(0xFF2E6664)],
            ),
            boxShadow: [
              BoxShadow(color: AppPalette.shadowInk, blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppPalette.cardStock, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featuredLabel.toUpperCase(),
                      style: const TextStyle(
                        color: AppPalette.mutedGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      situation.label,
                      style: const TextStyle(
                        color: AppPalette.cardStock,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryLabel,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.deepTeal : AppPalette.cardStock,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppPalette.deepTeal : AppPalette.borderTaupe),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.cardStock : AppPalette.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SituationChip extends StatelessWidget {
  const _SituationChip({
    super.key,
    required this.label,
    required this.icon,
    required this.visited,
    required this.visitedTooltip,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool visited;
  final String visitedTooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.cardStock,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(minWidth: 96),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.borderTaupe),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppPalette.deepTeal, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ),
              if (visited)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Tooltip(
                    message: visitedTooltip,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppPalette.mutedGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 12, color: AppPalette.ink),
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
