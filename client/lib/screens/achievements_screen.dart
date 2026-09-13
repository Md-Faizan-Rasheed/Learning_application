import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/achievement_data.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';

/// Achievements are derived purely from existing profile stats (XP, streak,
/// matches played) — no separate "unlocked" state is persisted anywhere,
/// since every criterion here is monotonic (once true, always true).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final achievements = achievementsFor(t, widget.profile);
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: AppHeader(
          title: t.profileAchievements, scrollController: _scrollController),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : (constraints.maxWidth >= 600 ? 2 : 1);

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            t.achievementsUnlockedCount(
                                unlockedCount, achievements.length),
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
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: columns == 1 ? 3.2 : 2.4,
                            ),
                            itemBuilder: (context, i) =>
                                _AchievementTile(achievement: achievements[i]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: unlocked ? AppPalette.mutedGold : AppPalette.cardStock,
        border: unlocked
            ? null
            : Border.all(color: AppPalette.borderTaupe),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadowInk,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? AppPalette.cardStock.withValues(alpha: 0.35)
                  : AppPalette.borderTaupe,
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_rounded,
              color: unlocked ? AppPalette.ink : AppPalette.inkMuted,
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
                    color: AppPalette.ink,
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
                    color: unlocked
                        ? AppPalette.ink.withValues(alpha: 0.75)
                        : AppPalette.inkMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            IconButton(
              onPressed: () {
                final t = AppLocalizations.of(context)!;
                Share.share(
                    t.achievementShareText(achievement.title, t.appTitle));
              },
              icon: const Icon(Icons.share_rounded,
                  color: AppPalette.ink, size: 20),
              tooltip: AppLocalizations.of(context)!.share,
            ),
        ],
      ),
    );
  }
}
