import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../screens/practice_screen.dart';
import '../utils/league.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/category_picker_dialog.dart';
import '../widgets/fade_scroll_edge.dart';
import '../widgets/leaderboard.dart' show podiumGradients;
import '../widgets/loading_view.dart';

enum _Zone { promotion, safe, atRisk, none }

_Zone _zoneForRank(int rank) {
  if (rank <= 10) return _Zone.promotion;
  if (rank <= 20) return _Zone.safe;
  if (rank <= 30) return _Zone.atRisk;
  return _Zone.none;
}

Color _zoneColor(_Zone zone) {
  switch (zone) {
    case _Zone.promotion:
      return Colors.amber.shade700;
    case _Zone.safe:
      return Colors.blueGrey.shade400;
    case _Zone.atRisk:
      return Colors.red.shade400;
    case _Zone.none:
      return Colors.transparent;
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.token});

  final String token;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ProfileApi _api = ProfileApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  Profile? _profile;
  List<LeaderboardEntry> _top = [];
  List<LeaderboardEntry> _nearby = [];

  String _scope = 'global';
  List<LeaderboardEntry> _friendsTop = [];
  bool _loadingFriends = false;
  bool _friendsLoaded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchProfile(widget.token),
        _api.fetchLeaderboard(widget.token),
        _api.fetchNearbyLeaderboard(widget.token),
      ]);
      setState(() {
        _profile = results[0] as Profile;
        _top = results[1] as List<LeaderboardEntry>;
        _nearby = results[2] as List<LeaderboardEntry>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadFriendsLeaderboard() async {
    setState(() => _loadingFriends = true);
    try {
      final friends = await _api.fetchFriendsLeaderboard(widget.token);
      setState(() {
        _friendsTop = friends;
        _loadingFriends = false;
        _friendsLoaded = true;
      });
    } catch (e) {
      setState(() => _loadingFriends = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _startChallenge() async {
    final category = await showCategoryPicker(context, token: widget.token);
    if (category == null || !mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => PracticeScreen(lang: lang, category: category)))
        .then((_) => _load());
  }

  LeaderboardEntry? get _myEntry {
    for (final e in _top) {
      if (e.isMe) return e;
    }
    for (final e in _nearby) {
      if (e.isMe) return e;
    }
    return null;
  }

  int? get _myRank => _myEntry?.placement;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.leaderboardTitle,
        scrollController: (_loading || _error != null) ? null : _scrollController,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: _loading
                ? LoadingView(
                    message: t.leaderboardLoading,
                    icon: Icons.leaderboard_rounded)
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: _load, child: Text(t.retry)),
                            ],
                          ),
                        ),
                      )
                    : _buildBody(context, t),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations t) {
    final profile = _profile;
    final isEmpty = profile != null &&
        profile.totalXp == 0 &&
        profile.recentMatches.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 16, horizontalPadding, 32),
                children: [
                  _buildScopeToggle(context, t),
                  const SizedBox(height: 16),
                  if (_scope == 'friends')
                    _buildFriendsScope(context, t)
                  else if (isEmpty)
                    _buildEmptyState(context, t)
                  else ...[
                    _buildHero(context, t),
                    const SizedBox(height: 24),
                    _buildLeagueStrip(context, t),
                    const SizedBox(height: 24),
                    if (_top.isNotEmpty) ...[
                      _sectionTitle(context, t.leaderboardTitle),
                      const SizedBox(height: 12),
                      _buildPodium(context, t, _top),
                      const SizedBox(height: 16),
                      _buildFullList(context, t, _top),
                      const SizedBox(height: 24),
                    ],
                    _buildNearby(context, t),
                    const SizedBox(height: 24),
                    _sectionTitle(context, t.lbRewardsTitle),
                    const SizedBox(height: 12),
                    _buildRewards(context, t),
                    const SizedBox(height: 24),
                    _buildAchievements(context, t),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800));
  }

  Widget _buildScopeToggle(BuildContext context, AppLocalizations t) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'global', label: Text(t.lbGlobalTab)),
              ButtonSegment(value: 'friends', label: Text(t.lbFriendsTab)),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              setState(() => _scope = s.first);
              if (_scope == 'friends' && !_friendsLoaded) {
                _loadFriendsLeaderboard();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsScope(BuildContext context, AppLocalizations t) {
    if (_loadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Just me — no accepted friends yet.
    if (_friendsTop.length <= 1) {
      final colors = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded,
                size: 40, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(t.lbFriendsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      );
    }
    return Column(
      children: [
        _buildPodium(context, t, _friendsTop),
        const SizedBox(height: 16),
        _buildFullList(context, t, _friendsTop),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_circle_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            t.lbEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            t.lbEmptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: colors.primary),
              onPressed: _startChallenge,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(t.lbEmptyCta,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    final profile = _profile!;
    final rank = _myRank;
    final myIndex = _nearby.indexWhere((e) => e.isMe);
    final above = myIndex > 0 ? _nearby[myIndex - 1] : null;

    String gapLine;
    if (above == null) {
      gapLine = t.lbLeadingPack;
    } else {
      final gap = above.totalXp - profile.totalXp;
      gapLine = gap > 0
          ? t.lbGapToNext(gap, above.displayName)
          : t.lbOneMoreChallenge;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 2),
                ),
                child: Center(
                  child: Text(
                    profile.displayName.trim().isNotEmpty
                        ? profile.displayName.trim()[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank != null ? t.lbYourRank(rank) : profile.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      t.xpTotal(profile.totalXp),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(gapLine,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: colors.primary),
              onPressed: _startChallenge,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(t.lbKeepLearning,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueStrip(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    final league = leagueForXp(_profile!.totalXp);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.lbLeagueSectionTitle,
              style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: FadeScrollEdge(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: League.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final tier = League.values[i];
                  final tierInfo = LeagueInfo(
                    league: tier,
                    currentThreshold: 0,
                    nextThreshold: null,
                    xpIntoLeague: 0,
                  );
                  final active = tier == league.league;
                  return Container(
                    width: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(colors: tierInfo.colors)
                          : null,
                      color: active
                          ? null
                          : colors.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: active
                          ? null
                          : Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tierInfo.icon,
                            color:
                                active ? Colors.white : colors.onSurfaceVariant,
                            size: 22),
                        const SizedBox(height: 4),
                        Text(
                          tierInfo.name(t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                active ? Colors.white : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: league.progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: colors.outlineVariant.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(league.colors.first),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            league.xpToNext == null
                ? t.lbMaxLeague
                : t.lbXpToNextLeague(league.xpToNext!,
                    leagueForXp(league.nextThreshold!).name(t)),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(BuildContext context, AppLocalizations t,
      List<LeaderboardEntry> entries) {
    final top3 = entries.take(3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();
    final order =
        top3.length == 3 ? [1, 0, 2] : List.generate(top3.length, (i) => i);

    return SizedBox(
      height: 202,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final i in order)
            if (i < top3.length)
              Expanded(child: _PodiumSlot(entry: top3[i], index: i, t: t)),
        ],
      ),
    );
  }

  Widget _buildFullList(BuildContext context, AppLocalizations t,
      List<LeaderboardEntry> entries) {
    final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
    if (rest.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final entry in rest) ...[
          _LeaderboardRow(entry: entry, t: t),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildNearby(BuildContext context, AppLocalizations t) {
    if (_nearby.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final myIndex = _nearby.indexWhere((e) => e.isMe);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.lbYourCompetition,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (int i = 0; i < _nearby.length; i++) ...[
            _NearbyRow(entry: _nearby[i], t: t),
            if (i != _nearby.length - 1) const SizedBox(height: 6),
          ],
          if (myIndex > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _startChallenge,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t.lbEarnXp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewards(BuildContext context, AppLocalizations t) {
    final rank = _myRank;
    final tiers = [
      _RewardTier(
          icon: Icons.emoji_events_rounded,
          label: t.lbReward1st,
          colors: podiumGradients[0],
          inRange: rank != null && rank <= 1),
      _RewardTier(
          icon: Icons.emoji_events_rounded,
          label: t.lbReward2nd,
          colors: podiumGradients[1],
          inRange: rank != null && rank <= 2),
      _RewardTier(
          icon: Icons.emoji_events_rounded,
          label: t.lbReward3rd,
          colors: podiumGradients[2],
          inRange: rank != null && rank <= 3),
      _RewardTier(
        icon: Icons.stars_rounded,
        label: t.lbRewardTop10(500),
        colors: const [Color(0xFF34D399), Color(0xFF059669)],
        inRange: rank != null && rank <= 10,
      ),
      _RewardTier(
        icon: Icons.military_tech_rounded,
        label: t.lbRewardTop20,
        colors: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
        inRange: rank != null && rank <= 20,
      ),
    ];

    return SizedBox(
      height: 136,
      child: FadeScrollEdge(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tiers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _RewardCard(tier: tiers[i], t: t),
        ),
      ),
    );
  }

  Widget _buildAchievements(BuildContext context, AppLocalizations t) {
    final rank = _myRank;
    final achievements = [
      (
        t.lbAchTop10Title,
        t.lbAchTop10Desc,
        Icons.trending_up_rounded,
        const [Color(0xFF0EA5E9), Color(0xFF6366F1)],
        rank != null && rank <= 10
      ),
      (
        t.lbAchTop3Title,
        t.lbAchTop3Desc,
        Icons.emoji_events_rounded,
        podiumGradients[0],
        rank != null && rank <= 3
      ),
    ];

    return SizedBox(
      height: 108,
      child: FadeScrollEdge(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final (title, desc, icon, colors, unlocked) = achievements[i];
            return Container(
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: unlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors)
                    : null,
                color: unlocked ? null : Colors.grey.withValues(alpha: 0.12),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                            color: colors.first.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(unlocked ? icon : Icons.lock_rounded,
                      color: unlocked ? Colors.white : Colors.grey.shade600,
                      size: 22),
                  const Spacer(),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unlocked ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5)),
                  Text(desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unlocked
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.grey.shade500,
                          fontSize: 10.5)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot(
      {required this.entry, required this.index, required this.t});
  final LeaderboardEntry entry;
  final int index;
  final AppLocalizations t;

  double get _height => index == 0 ? 190 : (index == 1 ? 160 : 140);
  double get _avatarSize => index == 0 ? 64 : 52;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (index == 0)
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFFFD54F), size: 20),
          Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: podiumGradients[index]),
              boxShadow: [
                BoxShadow(
                    color: podiumGradients[index].first.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
              border: entry.isMe
                  ? Border.all(color: colors.primary, width: 3)
                  : null,
            ),
            child: Center(
              child: Text(
                entry.displayName.trim().isNotEmpty
                    ? entry.displayName.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: _avatarSize * 0.4,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
          Text(t.xpTotal(entry.totalXp),
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            height: _height * 0.32,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: podiumGradients[index]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            child: Text('#${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.t});
  final LeaderboardEntry entry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final zone = _zoneForRank(entry.placement);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isMe
            ? colors.primary.withValues(alpha: 0.10)
            : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: entry.isMe
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                  color: _zoneColor(zone),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('${entry.placement}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight:
                            entry.isMe ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14.5),
                  ),
                ),
                if (entry.isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(t.lbYouTag,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.streakDays > 0) ...[
                  const Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 15),
                  const SizedBox(width: 2),
                  Text('${entry.streakDays}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    t.xpTotal(entry.totalXp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.entry, required this.t});
  final LeaderboardEntry entry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isMe
            ? colors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 28,
              child: Text('#${entry.placement}',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.isMe ? t.lbYouTag : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          Text(t.xpTotal(entry.totalXp),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RewardTier {
  const _RewardTier(
      {required this.icon,
      required this.label,
      required this.colors,
      required this.inRange});
  final IconData icon;
  final String label;
  final List<Color> colors;
  final bool inRange;
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.tier, required this.t});
  final _RewardTier tier;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: tier.inRange
                ? tier.colors.first.withValues(alpha: 0.6)
                : colors.outlineVariant,
            width: tier.inRange ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: tier.inRange
                      ? tier.colors
                      : [Colors.grey.shade400, Colors.grey.shade500]),
              shape: BoxShape.circle,
            ),
            child: Icon(tier.icon, color: Colors.white, size: 18),
          ),
          const Spacer(),
          Text(tier.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            tier.inRange ? t.lbRewardInRange : t.lbRewardLocked,
            style: TextStyle(
                fontSize: 10.5,
                color:
                    tier.inRange ? tier.colors.first : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
