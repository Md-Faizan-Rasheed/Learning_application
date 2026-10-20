import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import 'daily_maze_screen.dart';
import 'endless_home_screen.dart';
import 'responsive/maze_breakpoints.dart';
import 'two_player_race_screen.dart';

/// Part C — the shared entry point for every alternative play mode, per
/// the spec's "Mode Picker screen reachable from the feature home" with
/// responsive cards (a column on a phone, more columns on a wide
/// screen). Daily Maze (C2), Endless (C3) and the local 2-player race
/// (C6) — C1's ghost racing and C4/C5's no-hints/reverse options are
/// pause-menu-level toggles on the existing campaign instead, not
/// separate modes someone would pick *here*.
class MazeModePickerScreen extends StatelessWidget {
  const MazeModePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
                            t.mazeModePickerTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760
                            ? 3
                            : constraints.maxWidth >= 500
                                ? 2
                                : 1;
                        return GridView.count(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: columns == 1 ? 3.2 : 1.1,
                          children: [
                            _ModeCard(
                              icon: Icons.calendar_today_rounded,
                              title: t.mazeDailyTitle,
                              subtitle: t.mazeModeDailySubtitle,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const DailyMazeScreen()),
                              ),
                            ),
                            _ModeCard(
                              icon: Icons.all_inclusive_rounded,
                              title: t.mazeEndlessTitle,
                              subtitle: t.mazeModeEndlessSubtitle,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const EndlessHomeScreen()),
                              ),
                            ),
                            _ModeCard(
                              icon: Icons.people_alt_rounded,
                              title: t.mazeTwoPlayerTitle,
                              subtitle: t.mazeModeTwoPlayerSubtitle,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => TwoPlayerRaceScreen()),
                              ),
                            ),
                          ],
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: MazeColors.boardPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MazeColors.boardBorder),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 36, color: MazeColors.destinationIcon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MazeColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: MazeColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
