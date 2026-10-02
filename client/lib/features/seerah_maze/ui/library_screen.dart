import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_destination_icons.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_facts.dart';
import '../data/maze_levels.dart';
import '../models/maze_level.dart';
import 'responsive/maze_breakpoints.dart';

/// B4 — the collectible-fact Library: a grid of all 10 levels, each a
/// locked silhouette until its scroll has been found, showing the
/// real fact once it has. No questions, no scoring beyond the "X/10
/// found" count in the header — finding one is the whole point.
class MazeLibraryScreen extends StatelessWidget {
  const MazeLibraryScreen({super.key, required this.collectedFactLevelIds});

  final Set<int> collectedFactLevelIds;

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
                            t.mazeLibraryTitle,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_stories_rounded,
                                  color: MazeColors.scrollCap, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                t.mazeLibraryCount(
                                    collectedFactLevelIds.length, kMazeLevels.length),
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: kMazeLevels.length,
                      itemBuilder: (context, index) {
                        final level = kMazeLevels[index];
                        final found = collectedFactLevelIds.contains(level.id);
                        return _FactCard(level: level, found: found);
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

class _FactCard extends StatelessWidget {
  const _FactCard({required this.level, required this.found});

  final MazeLevel level;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Semantics(
      button: found,
      label: found
          ? t.mazeLibraryCardFoundSemantics(level.id)
          : t.mazeLibraryCardLockedSemantics(level.id),
      excludeSemantics: true,
      child: InkWell(
        onTap: found ? () => _showFactDialog(context, level) : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: found ? MazeColors.boardPanel : MazeColors.boardPanel.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: found ? MazeColors.scrollCap : MazeColors.boardBorder,
              width: found ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                found ? mazeDestinationIconFor(level.destinationKind) : Icons.lock_rounded,
                size: 32,
                color: found
                    ? MazeColors.destinationIcon
                    : MazeColors.wallOutline.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                t.mazeLevelNumber(level.id),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: found ? Colors.white : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFactDialog(BuildContext context, MazeLevel level) {
    MazeAudioService.instance.playButtonTap();
    final t = AppLocalizations.of(context)!;
    final levelText = mazeLevelTextFor(t, level.id);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: MazeColors.boardPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mazeDestinationIconFor(level.destinationKind),
                  size: 36, color: MazeColors.destinationIcon),
              const SizedBox(height: 10),
              Text(
                t.mazeLevelRoute(levelText.character, levelText.destination),
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                mazeFactTextFor(t, level.id),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.mazeLibraryCloseButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
