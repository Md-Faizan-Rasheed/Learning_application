import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../services/find_my_ayah_progress.dart';
import '../theme/app_theme.dart';
import '../utils/find_my_ayah_checkin.dart';
import '../utils/radial_layout.dart';
import '../utils/situation_data.dart';
import '../utils/tree_page_route.dart';
import '../widgets/app_header.dart';
import '../widgets/constellation_card_grid.dart';
import '../widgets/constellation_hero.dart';
import '../widgets/constellation_map.dart' show kStarCream;
import '../widgets/leaf_card_sheet.dart';
import '../widgets/loading_view.dart';
import '../widgets/saved_situations_sheet.dart';
import '../widgets/situation_checkin_grid.dart';
import '../widgets/situation_search_sheet.dart';
import '../widgets/status_pill.dart';
import 'find_my_ayah_subtree_screen.dart';

/// "Find My Ayah" root screen, split into two tabs:
///
/// - **Check In** (default): the fast path — every situation across every
///   category as a flat, filterable, tappable grid, plus a daily featured
///   card. Tapping a situation opens its card directly, no intermediate
///   navigation. This exists because the dominant real use case is "I feel
///   X right now, help me," not "let me browse a tree."
/// - **Explore**: a [ConstellationHero] night sky — a bright anchor star
///   at center with the 5 categories fanned around it as linked stars,
///   tapping one still navigates to a category-scoped sub-tree
///   (`FindMyAyahSubTreeScreen`). Kept for people who want to wander the
///   sky rather than search it.
///
/// Both tabs share one progress ledger ([FindMyAyahProgress]): opening a
/// situation from either tab marks it visited (which makes its Explore
/// star shine and badges its Check In chip) and, at most once per day,
/// reports a check-in to the real XP/streak backend via
/// [recordFindMyAyahOpen].
class FindMyAyahScreen extends StatefulWidget {
  const FindMyAyahScreen({super.key, this.token});

  final String? token;

  @override
  State<FindMyAyahScreen> createState() => _FindMyAyahScreenState();
}

class _FindMyAyahScreenState extends State<FindMyAyahScreen> {
  List<Category>? _categories;
  Set<String> _visited = {};
  int _tabIndex = 0;
  bool _showExploreHint = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await loadSituationCategories();
    final visited = await FindMyAyahProgress.instance.visitedSituationIds();
    final seenHint = await FindMyAyahProgress.instance.hasSeenExploreHint();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _visited = visited;
      _showExploreHint = !seenHint;
    });
  }

  void _dismissExploreHint() {
    if (!_showExploreHint) return;
    setState(() => _showExploreHint = false);
    FindMyAyahProgress.instance.markExploreHintSeen();
  }

  Future<void> _refreshVisited() async {
    final visited = await FindMyAyahProgress.instance.visitedSituationIds();
    if (mounted) setState(() => _visited = visited);
  }

  int get _totalSituations =>
      _categories?.fold<int>(0, (n, c) => n + c.situations.length) ?? 0;

  Future<void> _openSituation(Category category, Situation situation) async {
    final before = _visited.length;
    final outcome = await recordFindMyAyahOpen(
      token: widget.token,
      situationId: situation.id,
      visitedCountBefore: before,
    );
    if (!mounted) return;
    if (outcome.grew) {
      setState(() => _visited = {..._visited, situation.id});
    }
    await showLeafCardSheet(context, category: category, situation: situation);
    if (!mounted || outcome.reward == null) return;
    _showCheckInReward(outcome.reward!);
  }

  void _showCheckInReward(ActivityResult reward) {
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppPalette.mutedGold),
            const SizedBox(width: 8),
            Flexible(
              child: Text('${t.rewardXpBadge(reward.xpEarned)} · ${t.rewardStreakDays(reward.streakDays)}'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(Category category) {
    _dismissExploreHint();
    Navigator.of(context)
        .push(buildTreeRoute((_) => FindMyAyahSubTreeScreen(category: category, token: widget.token)))
        .then((_) => _refreshVisited());
  }

  Future<void> _openSearch() async {
    final categories = _categories;
    if (categories == null) return;
    final result = await showSituationSearchSheet(context, categories: categories);
    if (result == null || !mounted) return;
    await Navigator.of(context).push(
      buildTreeRoute((_) => FindMyAyahSubTreeScreen(
            category: result.category,
            initialSituationId: result.situation.id,
            token: widget.token,
          )),
    );
    _refreshVisited();
  }

  Future<void> _openSaved() async {
    final categories = _categories;
    if (categories == null) return;
    final result = await showSavedSituationsSheet(context, categories: categories);
    if (result == null || !mounted) return;
    await Navigator.of(context).push(
      buildTreeRoute((_) => FindMyAyahSubTreeScreen(
            category: result.category,
            initialSituationId: result.situation.id,
            initialRefIndex: result.refIndex,
            token: widget.token,
          )),
    );
    _refreshVisited();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final categories = _categories;

    return Scaffold(
      backgroundColor: AppPalette.parchment,
      appBar: AppHeader(
        title: t.fmaHeaderPrompt,
        actions: [
          IconButton(
            onPressed: categories == null ? null : _openSaved,
            icon: const Icon(Icons.bookmark_rounded),
            tooltip: t.fmaSavedTitle,
          ),
          IconButton(
            onPressed: categories == null ? null : _openSearch,
            icon: const Icon(Icons.search_rounded),
            tooltip: t.fmaSearchHint,
          ),
        ],
      ),
      body: SafeArea(
        child: categories == null
            ? LoadingView(message: t.fmaLoading, icon: Icons.auto_awesome_rounded)
            : Column(
                children: [
                  _buildTabBar(t),
                  _buildProgressRow(t),
                  Expanded(
                    child: _tabIndex == 0
                        ? SituationCheckInGrid(
                            categories: categories,
                            visitedSituationIds: _visited,
                            onOpen: _openSituation,
                          )
                        : Column(
                            children: [
                              if (_showExploreHint)
                                _ExploreHintBanner(text: t.fmaExploreHint, onDismiss: _dismissExploreHint),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final nodes = _buildNodes(categories, t);
                                    return constraints.maxWidth < kConstellationGridBreakpoint
                                        ? ConstellationCardGrid(nodes: nodes)
                                        : ConstellationHero(nodes: nodes);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, icon: const Icon(Icons.favorite_rounded), label: Text(t.fmaTabCheckIn)),
          ButtonSegment(value: 1, icon: const Icon(Icons.nights_stay_rounded), label: Text(t.fmaTabExplore)),
        ],
        selected: {_tabIndex},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => setState(() => _tabIndex = selection.first),
      ),
    );
  }

  Widget _buildProgressRow(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: StatusPill(
          label: t.fmaProgressCount(_visited.length, _totalSituations),
          tone: StatusTone.info,
          icon: Icons.local_florist_rounded,
        ),
      ),
    );
  }

  List<RadialNode> _buildNodes(List<Category> categories, AppLocalizations t) {
    return [
      RadialNode(label: t.fmaTreeRootLabel, ring: 0),
      for (final category in categories)
        RadialNode(
          label: category.label,
          ring: 1,
          onTap: () => _openCategory(category),
          visited: category.situations.every((s) => _visited.contains(s.id)),
        ),
    ];
  }
}

/// One-time nudge for the constellation's non-obvious "stars are buttons"
/// interaction — shown once (tracked by [FindMyAyahProgress]), dismissed
/// either explicitly or the moment a star is actually tapped.
class _ExploreHintBanner extends StatelessWidget {
  const _ExploreHintBanner({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppPalette.deepTeal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: kStarCream, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded, size: 16, color: kStarCream),
            ),
          ],
        ),
      ),
    );
  }
}
