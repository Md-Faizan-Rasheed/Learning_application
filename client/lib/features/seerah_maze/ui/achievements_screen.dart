import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../logic/achievements/achievement_inputs_loader.dart';
import '../logic/achievements/achievement_text.dart';
import '../models/maze_achievement.dart';
import 'responsive/maze_breakpoints.dart';

/// D1 — a read-only view over achievements computed from data every
/// other part of this feature already persists (see
/// logic/achievements/achievement_inputs_loader.dart). No new save state
/// of its own.
class MazeAchievementsScreen extends StatefulWidget {
  const MazeAchievementsScreen({super.key});

  @override
  State<MazeAchievementsScreen> createState() => _MazeAchievementsScreenState();
}

class _MazeAchievementsScreenState extends State<MazeAchievementsScreen> {
  MazeAchievementInputs? _inputs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inputs = await loadMazeAchievementInputs();
    if (!mounted) return;
    setState(() => _inputs = inputs);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final inputs = _inputs;
    final unlockedCount =
        inputs == null ? 0 : kMazeAchievements.where((a) => a.isUnlocked(inputs)).length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: MazeColors.background,
          ),
        ),
        child: SafeArea(
          child: MazeClampedTextScale(
            child: MazeResponsiveBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Transform.flip(
                            flipX: Directionality.of(context) == TextDirection.rtl,
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            t.mazeAchievementsScreenTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$unlockedCount/${kMazeAchievements.length}',
                            style:
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: inputs == null
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: kMazeAchievements.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final def = kMazeAchievements[index];
                              final text = mazeAchievementTextFor(t, def.id);
                              final progress = def.progressOf(inputs);
                              final unlocked = progress >= 1.0;
                              return _AchievementTile(
                                icon: def.icon,
                                title: text.title,
                                description: text.description,
                                progress: progress,
                                unlocked: unlocked,
                                unlockedLabel: t.mazeAchievementUnlockedSemantics,
                                lockedLabel: t.mazeAchievementLockedSemantics,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.unlocked,
    required this.unlockedLabel,
    required this.lockedLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final double progress;
  final bool unlocked;
  final String unlockedLabel;
  final String lockedLabel;

  @override
  Widget build(BuildContext context) {
    final dim = unlocked ? 1.0 : 0.45;
    return Semantics(
      label: '$title. $description. ${unlocked ? unlockedLabel : lockedLabel}.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MazeColors.boardPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MazeColors.boardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: unlocked
                    ? MazeColors.star.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: unlocked ? MazeColors.star : Colors.white.withValues(alpha: dim),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: dim),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: dim * 0.75), fontSize: 12),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: MazeColors.wall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unlocked) const Icon(Icons.check_circle_rounded, color: MazeColors.star, size: 22),
          ],
        ),
      ),
    );
  }
}
