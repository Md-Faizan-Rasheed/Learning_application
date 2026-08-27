import 'package:flutter/material.dart';

import '../utils/level.dart';

class RewardCard extends StatelessWidget {
  final int? xpEarned;
  final int? streakDays;
  final int? totalXp;
  final List<String> questsCompleted;

  const RewardCard({
    Key? key,
    this.xpEarned,
    this.streakDays,
    this.totalXp,
    required this.questsCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = totalXp != null ? levelForXp(totalXp!) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (xpEarned != null)
                Expanded(
                  child: _RewardStat(
                    icon: Icons.stars_rounded,
                    label: '+$xpEarned XP',
                  ),
                ),
              if (xpEarned != null && streakDays != null)
                const SizedBox(width: 12),
              if (streakDays != null)
                Expanded(
                  child: _RewardStat(
                    icon: Icons.local_fire_department,
                    label: '$streakDays day streak',
                  ),
                ),
            ],
          ),
          if (level != null) ...[
            const SizedBox(height: 16),
            Text(
              'Lv.${level.level} · ${level.title}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: level.progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
          if (questsCompleted.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Quests completed',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            for (final quest in questsCompleted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colors.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quest,
                        style: TextStyle(color: colors.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  const _RewardStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colors.onPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
