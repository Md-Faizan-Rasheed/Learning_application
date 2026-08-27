import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../widgets/app_header.dart';

class _Achievement {
  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.unlocked,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final bool unlocked;
}

/// Achievements are derived purely from existing profile stats (XP, streak,
/// matches played) — no separate "unlocked" state is persisted anywhere,
/// since every criterion here is monotonic (once true, always true).
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.profile});

  final Profile profile;

  List<_Achievement> get _achievements {
    final xp = profile.totalXp;
    final streak = profile.streakDays;
    final matches = profile.recentMatches.length;

    return [
      _Achievement(
        title: 'First Steps',
        description: 'Play your first match',
        icon: Icons.flag_rounded,
        colors: const [Color(0xFF16A34A), Color(0xFF0D9488)],
        unlocked: xp > 0 || matches > 0,
      ),
      _Achievement(
        title: 'Century Club',
        description: 'Earn 100 total XP',
        icon: Icons.stars_rounded,
        colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
        unlocked: xp >= 100,
      ),
      _Achievement(
        title: 'XP Master',
        description: 'Earn 500 total XP',
        icon: Icons.workspace_premium_rounded,
        colors: const [Color(0xFF7C3AED), Color(0xFF2563EB)],
        unlocked: xp >= 500,
      ),
      _Achievement(
        title: 'XP Legend',
        description: 'Earn 2000 total XP',
        icon: Icons.auto_awesome_rounded,
        colors: const [Color(0xFFDB2777), Color(0xFF9333EA)],
        unlocked: xp >= 2000,
      ),
      _Achievement(
        title: 'On Fire',
        description: 'Reach a 3-day streak',
        icon: Icons.local_fire_department_rounded,
        colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
        unlocked: streak >= 3,
      ),
      _Achievement(
        title: 'Unstoppable',
        description: 'Reach a 7-day streak',
        icon: Icons.whatshot_rounded,
        colors: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
        unlocked: streak >= 7,
      ),
      _Achievement(
        title: 'Dedicated Scholar',
        description: 'Reach a 30-day streak',
        icon: Icons.emoji_events_rounded,
        colors: const [Color(0xFFCA8A04), Color(0xFFA16207)],
        unlocked: streak >= 30,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final achievements = _achievements;
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: const AppHeader(title: 'Achievements'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$unlockedCount / ${achievements.length} unlocked',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: achievements.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: columns == 1 ? 3.2 : 2.4,
                      ),
                      itemBuilder: (context, i) => _AchievementTile(achievement: achievements[i]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: achievement.colors,
              )
            : null,
        color: unlocked ? null : Colors.grey.withValues(alpha: 0.12),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: achievement.colors.first.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? Colors.white.withValues(alpha: 0.22) : Colors.grey.withValues(alpha: 0.25),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_rounded,
              color: unlocked ? Colors.white : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  achievement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade500,
                    fontSize: 11.5,
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
