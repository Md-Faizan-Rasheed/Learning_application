import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/campaign_path_painter.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_destination_icons.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_chapters.dart';
import '../data/maze_levels.dart';
import '../data/maze_progress_repository.dart';
import '../models/maze_level.dart';
import '../models/maze_progress.dart';
import 'library_screen.dart';
import 'maze_game_screen.dart';
import 'responsive/maze_breakpoints.dart';
import 'story_intro_sheet.dart';

/// The feature's one entry screen: an illustrated, winding journey through
/// all 10 levels (B1) — locked nodes dimmed, completed ones showing earned
/// stars, the next playable one pulsing, grouped into chapter bands by era.
/// Owns the single in-memory [MazeProgress] this whole feature shares,
/// loaded once from (and persisted back to) [MazeProgressRepository] —
/// every descendant screen (game, pause menu) only ever sees a copy and
/// bubbles changes back up here via callbacks, so this is the one place
/// that actually writes to disk.
class SeerahMazeLevelSelectScreen extends StatefulWidget {
  const SeerahMazeLevelSelectScreen({super.key});

  @override
  State<SeerahMazeLevelSelectScreen> createState() => _SeerahMazeLevelSelectScreenState();
}

class _SeerahMazeLevelSelectScreenState extends State<SeerahMazeLevelSelectScreen> {
  static const _repository = MazeProgressRepository();

  MazeProgress _progress = const MazeProgress();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final loaded = await _repository.load();
    if (!mounted) return;
    setState(() {
      _progress = loaded;
      _loading = false;
    });
    MazeAudioService.instance.enabled = loaded.soundEnabled;
  }

  void _onLevelCompleted(int levelId, int stars, int timeSeconds) {
    setState(() {
      final bestStars = (_progress.starsByLevel[levelId] ?? 0);
      final bestTime = _progress.bestTimeSecondsByLevel[levelId];
      _progress = _progress.copyWith(
        highestUnlockedLevel:
            levelId >= _progress.highestUnlockedLevel && levelId < kMazeLevels.length
                ? levelId + 1
                : _progress.highestUnlockedLevel,
        starsByLevel: {
          ..._progress.starsByLevel,
          levelId: stars > bestStars ? stars : bestStars,
        },
        bestTimeSecondsByLevel: {
          ..._progress.bestTimeSecondsByLevel,
          if (bestTime == null || timeSeconds < bestTime) levelId: timeSeconds,
        },
      );
    });
    _repository.save(_progress);
  }

  void _onProgressChanged(MazeProgress updated) {
    setState(() => _progress = updated);
    _repository.save(_progress);
  }

  Future<void> _openLevel(MazeLevel level) async {
    final unlocked = level.id <= _progress.highestUnlockedLevel;
    if (!unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mazeLockedMessage)),
      );
      return;
    }
    MazeAudioService.instance.playButtonTap();
    final started = await showMazeStoryIntroSheet(context, level);
    if (started != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MazeGameScreen(
          level: level,
          isLastLevel: level.id == kMazeLevels.length,
          initialProgress: _progress,
          onLevelCompleted: _onLevelCompleted,
          onProgressChanged: _onProgressChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final totalStars = _progress.starsByLevel.values.fold(0, (a, b) => a + b);
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
                            t.mazeScreenTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: t.mazeLibraryButtonSemantics,
                          child: IconButton(
                            icon: const Icon(Icons.auto_stories_rounded, color: Colors.white),
                            onPressed: () {
                              MazeAudioService.instance.playButtonTap();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MazeLibraryScreen(
                                    collectedFactLevelIds: _progress.collectedFactLevelIds,
                                  ),
                                ),
                              );
                            },
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
                              const Icon(Icons.star_rounded, color: MazeColors.star, size: 16),
                              const SizedBox(width: 4),
                              Text('$totalStars/${kMazeLevels.length * 3}',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _JourneyPath(progress: _progress, onTapLevel: _openLevel),
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

/// B1 — the winding journey map: 10 level nodes connected by the same
/// curved/dashed path treatment the Seerah Campaign Map already uses
/// (reused directly from widgets/campaign_path_painter.dart rather than
/// re-implemented, since it's generic — curve geometry, dash pattern, and
/// the traveling-dot glow don't know anything about campaigns or mazes),
/// grouped into chapter bands, with the current level auto-centered the
/// first time the map lays out.
///
/// Owns exactly two ambient animations total regardless of level count —
/// one pulse for the current node, one traveling dot along the cleared
/// path — the same discipline the campaign map uses, so this never scales
/// per-node.
class _JourneyPath extends StatefulWidget {
  const _JourneyPath({required this.progress, required this.onTapLevel});

  final MazeProgress progress;
  final void Function(MazeLevel level) onTapLevel;

  @override
  State<_JourneyPath> createState() => _JourneyPathState();
}

class _JourneyPathState extends State<_JourneyPath> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final Animation<double> _pulseScale;
  final _scrollController = ScrollController();
  bool _centeredOnce = false;

  static const double _nodeDiameter = 56;
  static const double _currentNodeDiameter = 80;
  static const double _nodeBoxWidth = 120;
  static const double _verticalSpacing = 150;
  static const double _topPadding = 48;
  static const double _bottomPadding = 32;
  static const double _horizontalPadding = 24;
  static const List<double> _xFractions = [0.24, 0.76, 0.5];

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _dotController = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls so the current level's node sits roughly a third of the way
  /// down the viewport — "focus automatically centered on the current
  /// node" per the spec, biased slightly upward so the path ahead stays
  /// visible too, not just the path already walked.
  void _centerOnCurrent(double targetY, double viewportHeight, double maxScrollExtent) {
    if (_centeredOnce) return;
    _centeredOnce = true;
    final target = (targetY - viewportHeight / 3).clamp(0.0, maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = widget.progress;
    final currentLevelId = progress.highestUnlockedLevel.clamp(1, kMazeLevels.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pathWidth =
            (constraints.maxWidth - _horizontalPadding * 2).clamp(1.0, double.infinity);
        final centers = <Offset>[];
        for (var i = 0; i < kMazeLevels.length; i++) {
          final level = kMazeLevels[i];
          final diameter = level.id == currentLevelId ? _currentNodeDiameter : _nodeDiameter;
          final radius = diameter / 2;
          final x =
              (pathWidth * _xFractions[i % _xFractions.length]).clamp(radius, pathWidth - radius);
          final y = _topPadding + radius + i * _verticalSpacing;
          centers.add(Offset(x, y));
        }
        final totalHeight =
            centers.isEmpty ? 0.0 : centers.last.dy + _currentNodeDiameter / 2 + _bottomPadding;
        final viewportHeight = constraints.maxHeight;
        final maxScrollExtent = (totalHeight - viewportHeight).clamp(0.0, double.infinity);
        _centerOnCurrent(centers[currentLevelId - 1].dy, viewportHeight, maxScrollExtent);

        final segments = <CampaignPathSegment>[
          for (var i = 0; i < kMazeLevels.length - 1; i++)
            CampaignPathSegment(
              start: centers[i],
              end: centers[i + 1],
              traveled: kMazeLevels[i + 1].id <= progress.highestUnlockedLevel,
            ),
        ];

        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: SizedBox(
              height: totalHeight,
              width: pathWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final chapter in kMazeChapters) _chapterBand(chapter, centers, pathWidth),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _dotController,
                      builder: (context, _) => CustomPaint(
                        painter: CampaignPathPainter(
                          segments: segments,
                          traveledColor: AppPalette.mutedGold,
                          aheadColor: colors.outlineVariant.withValues(alpha: 0.4),
                          dotProgress: _dotController.value,
                          dotColor: AppPalette.mutedGold,
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < kMazeLevels.length; i++)
                    Positioned(
                      left: centers[i].dx - _nodeBoxWidth / 2,
                      top: centers[i].dy -
                          (kMazeLevels[i].id == currentLevelId
                                  ? _currentNodeDiameter
                                  : _nodeDiameter) /
                              2,
                      width: _nodeBoxWidth,
                      child: AnimatedBuilder(
                        animation: _pulseScale,
                        builder: (context, _) => _LevelNode(
                          level: kMazeLevels[i],
                          unlocked: kMazeLevels[i].id <= progress.highestUnlockedLevel,
                          isCurrent: kMazeLevels[i].id == currentLevelId,
                          stars: progress.starsByLevel[kMazeLevels[i].id] ?? 0,
                          pulseScale: kMazeLevels[i].id == currentLevelId ? _pulseScale.value : 1.0,
                          onTap: () => widget.onTapLevel(kMazeLevels[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A faint rounded band spanning every node in [chapter], with its era
  /// title pinned at the top — B1's "chapter regions".
  Widget _chapterBand(MazeChapter chapter, List<Offset> centers, double pathWidth) {
    final firstIndex = chapter.firstLevelId - 1;
    final lastIndex = chapter.lastLevelId - 1;
    if (firstIndex >= centers.length || lastIndex >= centers.length) {
      return const SizedBox.shrink();
    }
    const margin = 70.0;
    final top = centers[firstIndex].dy - margin;
    final bottom = centers[lastIndex].dy + margin;

    return Builder(
      builder: (context) {
        final t = AppLocalizations.of(context)!;
        return Positioned(
          left: 0,
          right: 0,
          top: top,
          height: bottom - top,
          child: Container(
            decoration: BoxDecoration(
              color: chapter.id.isOdd
                  ? AppPalette.mutedGold.withValues(alpha: 0.055)
                  : AppPalette.cardStock.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              mazeChapterTitleFor(t, chapter.id).toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.unlocked,
    required this.isCurrent,
    required this.stars,
    required this.pulseScale,
    required this.onTap,
  });

  final MazeLevel level;
  final bool unlocked;
  final bool isCurrent;
  final int stars;
  final double pulseScale;
  final VoidCallback onTap;

  static const double _diameter = 56;
  static const double _currentDiameter = 80;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final levelText = mazeLevelTextFor(t, level.id);
    final diameter = isCurrent ? _currentDiameter : _diameter;

    Widget circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? MazeColors.boardPanel : MazeColors.boardPanel.withValues(alpha: 0.45),
        border: Border.all(
          color: isCurrent ? MazeColors.wall : MazeColors.boardBorder,
          width: isCurrent ? 3 : 1.5,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                    color: MazeColors.wall.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 2)
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: unlocked ? 1 : 0.55,
        child: Icon(
          unlocked ? mazeDestinationIconFor(level.destinationKind) : Icons.lock_rounded,
          color:
              unlocked ? MazeColors.destinationIcon : MazeColors.wallOutline.withValues(alpha: 0.7),
          size: isCurrent ? 32 : 24,
        ),
      ),
    );
    if (isCurrent) circle = Transform.scale(scale: pulseScale, child: circle);

    return Semantics(
      button: true,
      enabled: unlocked,
      label: unlocked
          ? t.mazeLevelSemanticsUnlocked(level.id, levelText.character, levelText.destination) +
              (stars > 0 ? t.mazeStarsEarnedSuffix(stars) : '')
          : t.mazeLevelSemanticsLocked(level.id),
      // Without this, the node's own route-name/star Text children merge
      // their automatic semantics into this label, doubling it up rather
      // than announcing the clean single label set above.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _currentDiameter,
              height: _currentDiameter,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  circle,
                  Positioned(
                    left: (_currentDiameter - diameter) / 2 - 2,
                    top: (_currentDiameter - diameter) / 2 - 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MazeColors.wall,
                        border: Border.all(color: MazeColors.boardPanel, width: 2),
                      ),
                      child: Text(
                        '${level.id}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.mazeLevelRoute(levelText.character, levelText.destination),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            if (unlocked) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: i < stars ? MazeColors.star : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
