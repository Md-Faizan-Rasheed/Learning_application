import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../screens/achievements_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../utils/level.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';
import '../widgets/streak_flame.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.token,
    this.name = 'Player',
  });

  final String? token;
  final String name;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileApi _api = ProfileApi();
  bool _loading = true;
  String? _error;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to see your profile.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _api.fetchProfile(token);
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'My Profile'),
      body: SafeArea(
        child: _loading
            ? const LoadingView(message: 'Loading your profile…', icon: Icons.person_rounded)
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : _buildProfile(_profile!),
      ),
    );
  }

  Widget _buildProfile(Profile profile) {
    final name = profile.displayName.isNotEmpty ? profile.displayName : widget.name;
    final level = levelForXp(profile.totalXp);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 900;
        final isTablet = width >= 600 && width < 900;

        final scale = _ProfileScale(
          avatarSize: isDesktop ? 128 : (isTablet ? 104 : 84),
          heroPadding: isDesktop ? 36 : (isTablet ? 28 : 20),
          nameFontSize: isDesktop ? 30 : (isTablet ? 26 : 22),
          cardIconSize: isDesktop ? 32 : (isTablet ? 30 : 26),
          cardValueFontSize: isDesktop ? 28 : (isTablet ? 26 : 22),
          cardGap: isDesktop ? 20 : (isTablet ? 16 : 12),
          sectionGap: isDesktop ? 32 : (isTablet ? 26 : 22),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 760 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 0 : (isTablet ? 24 : 16),
                24,
                isDesktop ? 0 : (isTablet ? 24 : 16),
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHero(name: name, level: level, scale: scale),
                  SizedBox(height: scale.sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.stars_rounded,
                          iconColor: Colors.amber.shade700,
                          value: '${profile.totalXp}',
                          label: 'Total XP',
                          scale: scale,
                        ),
                      ),
                      SizedBox(width: scale.cardGap),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orange,
                          value: '${profile.streakDays}',
                          label: 'Day Streak',
                          scale: scale,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: scale.sectionGap),
                  _StreakHighlight(streak: profile.streakDays, scale: scale),
                  SizedBox(height: scale.sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AchievementsScreen(profile: profile),
                            ),
                          ),
                          icon: const Icon(Icons.military_tech_rounded),
                          label: const Text('Achievements'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.token == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LeaderboardScreen(token: widget.token!),
                                    ),
                                  ),
                          icon: const Icon(Icons.leaderboard_rounded),
                          label: const Text('Leaderboard'),
                        ),
                      ),
                    ],
                  ),
                  if (profile.recentMatches.isNotEmpty) ...[
                    SizedBox(height: scale.sectionGap),
                    Text(
                      'Recent matches',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    for (final m in profile.recentMatches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MatchHistoryTile(match: m),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileScale {
  const _ProfileScale({
    required this.avatarSize,
    required this.heroPadding,
    required this.nameFontSize,
    required this.cardIconSize,
    required this.cardValueFontSize,
    required this.cardGap,
    required this.sectionGap,
  });

  final double avatarSize;
  final double heroPadding;
  final double nameFontSize;
  final double cardIconSize;
  final double cardValueFontSize;
  final double cardGap;
  final double sectionGap;
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.level,
    required this.scale,
  });

  final String name;
  final LevelInfo level;
  final _ProfileScale scale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: scale.heroPadding,
        vertical: scale.heroPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: scale.avatarSize,
                height: scale.avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: scale.avatarSize * 0.42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: Text(
                    'Lv.${level.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: scale.heroPadding * 0.6),
          Text(
            name.trim().isEmpty ? 'Player' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: scale.nameFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level.title,
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _XpProgressBar(level: level),
        ],
      ),
    );
  }
}

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({required this.level});

  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    final label = level.nextLevelXp == null
        ? 'Max level reached'
        : '${level.xpToNext} XP to Lv.${level.level + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: level.progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.scale,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final _ProfileScale scale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: scale.cardIconSize),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: scale.cardValueFontSize,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakHighlight extends StatelessWidget {
  const _StreakHighlight({required this.streak, required this.scale});

  final int streak;
  final _ProfileScale scale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: scale.heroPadding * 0.8, horizontal: scale.heroPadding),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          StreakFlame(streak: streak),
          const SizedBox(height: 6),
          Text(
            streak > 0 ? 'Keep the fire burning!' : 'Play today to start your streak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryTile extends StatelessWidget {
  const _MatchHistoryTile({required this.match});

  final MatchHistoryItem match;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final difficulty = match.difficulty.isEmpty
        ? 'Mixed'
        : '${match.difficulty[0].toUpperCase()}${match.difficulty.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Text(
              match.placement != null ? '#${match.placement}' : '—',
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$difficulty match', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '${match.finalScore ?? 0} pts',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
