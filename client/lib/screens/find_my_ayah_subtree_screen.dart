import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/find_my_ayah_progress.dart';
import '../theme/app_theme.dart';
import '../utils/find_my_ayah_checkin.dart';
import '../utils/radial_layout.dart';
import '../utils/situation_data.dart';
import '../widgets/app_header.dart';
import '../widgets/breadcrumb_trail.dart';
import '../widgets/constellation_card_grid.dart';
import '../widgets/constellation_hero.dart';
import '../widgets/leaf_card_sheet.dart';

/// One category's situations, full-screen — the "sub-tree" a root category
/// star navigates to from the Explore tab (see `find_my_ayah_screen.dart`).
/// Ring 0 becomes the current category itself (a fixed, non-interactive
/// anchor — "wherever the user currently is"), and its situations fan out
/// as Ring 2. This stays safe at any count (situations range 4-15 across
/// categories) because `radial_layout.dart`'s ring math shrinks and
/// spreads Ring 2 automatically as the node count grows, rather than a
/// fixed layout that would crowd or overflow at the high end.
class FindMyAyahSubTreeScreen extends StatefulWidget {
  const FindMyAyahSubTreeScreen({
    super.key,
    required this.category,
    this.initialSituationId,
    this.initialRefIndex = 0,
    this.token,
  });

  final Category category;

  /// When set (arriving here from search or a saved bookmark rather than
  /// tapping a leaf), the matching situation's card opens automatically
  /// once this screen has finished its entrance transition.
  final String? initialSituationId;
  final int initialRefIndex;

  /// Threaded through from the root screen so opening a card here can
  /// still report a daily check-in to the real XP/streak ledger — see
  /// `utils/find_my_ayah_checkin.dart`.
  final String? token;

  @override
  State<FindMyAyahSubTreeScreen> createState() => _FindMyAyahSubTreeScreenState();
}

class _FindMyAyahSubTreeScreenState extends State<FindMyAyahSubTreeScreen> {
  Set<String> _visited = {};

  @override
  void initState() {
    super.initState();
    _loadVisited();
    final targetId = widget.initialSituationId;
    if (targetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Situation? situation;
        for (final s in widget.category.situations) {
          if (s.id == targetId) {
            situation = s;
            break;
          }
        }
        if (situation != null) {
          _openSituation(situation, refIndex: widget.initialRefIndex);
        }
      });
    }
  }

  Future<void> _loadVisited() async {
    final visited = await FindMyAyahProgress.instance.visitedSituationIds();
    if (mounted) setState(() => _visited = visited);
  }

  Future<void> _openSituation(Situation situation, {int refIndex = 0}) async {
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
    await showLeafCardSheet(
      context,
      category: widget.category,
      situation: situation,
      initialRefIndex: refIndex,
    );
    if (!mounted || outcome.reward == null) return;
    final reward = outcome.reward!;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppPalette.parchment,
      appBar: AppHeader(
        title: widget.category.label,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            BreadcrumbTrail(items: [
              BreadcrumbItem(label: t.fmaTreeRootLabel, onTap: () => Navigator.of(context).pop()),
              BreadcrumbItem(label: widget.category.label),
            ]),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final nodes = _buildNodes();
                  return constraints.maxWidth < kConstellationGridBreakpoint
                      ? ConstellationCardGrid(nodes: nodes)
                      : ConstellationHero(nodes: nodes);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RadialNode> _buildNodes() {
    return [
      RadialNode(label: widget.category.label, ring: 0),
      for (final situation in widget.category.situations)
        RadialNode(
          label: situation.label,
          ring: 2,
          onTap: () => _openSituation(situation),
          visited: _visited.contains(situation.id),
        ),
    ];
  }
}
