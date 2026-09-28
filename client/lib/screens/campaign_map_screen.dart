import 'package:flutter/material.dart';

import '../api/campaign_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/campaign_path_painter.dart';
import '../widgets/loading_view.dart';
import 'multiplayer_screen.dart';

/// The Seerah movement-stages campaign: a linear progression through
/// campaign_stages. Tapping the current stage's "Play" starts a quick
/// match scoped to that stage directly — campaign matches are solo-vs-bots
/// by design (see MultiplayerScreen.campaignStageId), so there's no reason
/// to route through MultiplayerChoiceScreen's host/join-room options here.
///
/// Stages render along a winding vertical path (alternating left/right/
/// center) rather than a plain list — purely a layout choice; the fetch,
/// state derivation, and Play action below are unchanged.
class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({
    super.key,
    required this.token,
    required this.name,
    required this.lang,
  });

  final String token;
  final String name;
  final String lang;

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  final CampaignApi _api = CampaignApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<CampaignStage> _stages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stages = await _api.fetchStages(widget.token);
      setState(() {
        _stages = stages;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _playStage(CampaignStage stage) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => MultiplayerScreen(
            lang: widget.lang,
            name: widget.name,
            token: widget.token,
            category: 'seerah',
            campaignStageId: stage.slug,
          ),
        ))
        .then((_) => _load());
  }

  CampaignStage? get _currentStage {
    for (final s in _stages) {
      if (s.state == 'current') return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final current = _currentStage;
    return Scaffold(
      appBar: AppHeader(
        title: t.campaignMapTitle,
        scrollController:
            (_loading || _error != null || _stages.isEmpty) ? null : _scrollController,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: _loading
                ? LoadingView(
                    message: t.campaignMapLoading, icon: Icons.map_rounded)
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: Text(t.retry)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontalPadding =
                              constraints.maxWidth >= 600 ? 32.0 : 16.0;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: _CampaignPath(
                                  stages: _stages,
                                  lang: widget.lang,
                                  scrollController: _scrollController,
                                  horizontalPadding: horizontalPadding,
                                  // Leave room at the bottom so the floating
                                  // card below never covers the last node.
                                  bottomReserve: current == null ? 24 : 132,
                                  onPlayStage: _playStage,
                                ),
                              ),
                              if (current != null)
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: _CurrentStageCard(
                                    stage: current,
                                    lang: widget.lang,
                                    onPlay: () => _playStage(current),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// One thematic glyph per movement stage, reused across locked/current/
/// completed states — only the badge overlaid in the corner (check/lock/
/// percentage) changes with state. Falls back to a generic book icon for
/// any future stage slug this map doesn't know about yet.
const Map<String, IconData> _kStageIcons = {
  'tazkiyah': Icons.self_improvement_rounded,
  'secret_dawah': Icons.visibility_off_rounded,
  'open_dawah': Icons.campaign_rounded,
  'search_for_a_base': Icons.explore_rounded,
  'hijrah_relocation': Icons.flight_takeoff_rounded,
  'state_building': Icons.account_balance_rounded,
  'defense_consolidation': Icons.shield_rounded,
  'expansion_dominance': Icons.public_rounded,
  'completion': Icons.emoji_events_rounded,
};

IconData _iconForStage(String slug) => _kStageIcons[slug] ?? Icons.auto_stories_rounded;

/// The winding vertical path: stage nodes at alternating x-positions
/// (left/right/center, cycling every 3), connected by a curved line that's
/// solid/colored through reached stages and dashed/muted ahead of them.
/// Scrolls if the full stage list doesn't fit the viewport.
///
/// Owns the two ambient animations (current-stage pulse, traveling path
/// dot) via a single TickerProviderStateMixin. Flutter's own TickerMode
/// automatically suspends both the instant this route stops being the
/// visible one (e.g. Play pushes MultiplayerScreen on top) — the standard,
/// dependency-free way an AnimationController "gates on visibility" at the
/// route level. Within the screen there are only ever two animated things
/// total (one pulsing node, one traveling dot), never one controller per
/// node, so scrolling more locked/completed nodes into view adds no
/// animation cost.
class _CampaignPath extends StatefulWidget {
  const _CampaignPath({
    required this.stages,
    required this.lang,
    required this.scrollController,
    required this.horizontalPadding,
    required this.bottomReserve,
    required this.onPlayStage,
  });

  final List<CampaignStage> stages;
  final String lang;
  final ScrollController scrollController;
  final double horizontalPadding;
  final double bottomReserve;
  // Every node is playable, not just the current one — the backend never
  // gated find_match/create_room on progression (get_stage_id_by_slug just
  // resolves whatever slug it's given), so this was always safe to expose;
  // the lock/completed styling below is purely informational now, not a
  // functional restriction.
  final void Function(CampaignStage stage) onPlayStage;

  @override
  State<_CampaignPath> createState() => _CampaignPathState();
}

class _CampaignPathState extends State<_CampaignPath> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final Animation<double> _pulseScale;

  static const double _nodeDiameter = 56;
  static const double _currentNodeDiameter = 80;
  // Used for BOTH the Positioned offset below and _StageNode's own width, so
  // a node's circle always lands exactly on its path point regardless of
  // the label text beside it — a plain width mismatch here previously left
  // every node rendering visibly off-center from the path it sits on.
  static const double _nodeBoxWidth = 120;
  static const double _verticalSpacing = 132;
  static const double _topPadding = 36;
  // Cycles left/right/center, matching the mockup's alternating placement.
  static const List<double> _xFractions = [0.24, 0.76, 0.5];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stages = widget.stages;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pathWidth = constraints.maxWidth - widget.horizontalPadding * 2;
            final centers = <Offset>[];
            for (var i = 0; i < stages.length; i++) {
              final diameter =
                  stages[i].state == 'current' ? _currentNodeDiameter : _nodeDiameter;
              final radius = diameter / 2;
              final x = (pathWidth * _xFractions[i % _xFractions.length])
                  .clamp(radius, pathWidth - radius);
              final y = _topPadding + radius + i * _verticalSpacing;
              centers.add(Offset(x, y));
            }
            final totalHeight = stages.isEmpty
                ? 0.0
                : centers.last.dy + _currentNodeDiameter / 2 + widget.bottomReserve;

            final segments = <CampaignPathSegment>[
              for (var i = 0; i < stages.length - 1; i++)
                CampaignPathSegment(
                  start: centers[i],
                  end: centers[i + 1],
                  traveled: stages[i + 1].state != 'locked',
                ),
            ];

            return SingleChildScrollView(
              controller: widget.scrollController,
              padding:
                  EdgeInsets.fromLTRB(widget.horizontalPadding, 0, widget.horizontalPadding, 0),
              child: SizedBox(
                height: totalHeight,
                width: pathWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _dotController,
                        builder: (context, _) => CustomPaint(
                          painter: CampaignPathPainter(
                            segments: segments,
                            traveledColor: AppPalette.mutedGold,
                            aheadColor: colors.outlineVariant,
                            dotProgress: _dotController.value,
                            dotColor: AppPalette.mutedGold,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < stages.length; i++)
                      Positioned(
                        left: centers[i].dx - _nodeBoxWidth / 2,
                        top: centers[i].dy -
                            (stages[i].state == 'current'
                                    ? _currentNodeDiameter
                                    : _nodeDiameter) /
                                2,
                        width: _nodeBoxWidth,
                        child: _StageNode(
                          stage: stages[i],
                          lang: widget.lang,
                          icon: _iconForStage(stages[i].slug),
                          previousStageName:
                              i > 0 ? stages[i - 1].nameFor(widget.lang) : null,
                          pulseScale: stages[i].state == 'current' ? _pulseScale : null,
                          onTap: () => widget.onPlayStage(stages[i]),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A single circular stage marker. Every state shares the same thematic
/// glyph in the center; only a small corner badge (check/lock) and the
/// border/fill treatment change — except the current stage, whose node is
/// larger, ringed with a live progress arc, and glows/pulses to draw the
/// eye.
class _StageNode extends StatefulWidget {
  const _StageNode({
    required this.stage,
    required this.lang,
    required this.icon,
    required this.onTap,
    this.previousStageName,
    this.pulseScale,
  });

  final CampaignStage stage;
  final String lang;
  final IconData icon;
  final String? previousStageName;
  // Every node is tappable — locked/completed included; see
  // _CampaignPath.onPlayStage's doc comment for why that's safe.
  final VoidCallback onTap;
  // Only ever set for the current stage's node — animates just the circle
  // (glow + ring + fill) around its own center, so the label text beneath
  // it stays put instead of wobbling with it.
  final Animation<double>? pulseScale;

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode> {
  static const double _diameter = 56;
  static const double _currentOuter = 80;
  static const double _currentInner = 64;
  static const double _ringStroke = 5;

  bool _pressed = false;

  CampaignStage get stage => widget.stage;
  String get lang => widget.lang;
  IconData get icon => widget.icon;
  String? get previousStageName => widget.previousStageName;
  Animation<double>? get pulseScale => widget.pulseScale;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final pct = stage.target == 0 ? 0.0 : (stage.progress / stage.target).clamp(0.0, 1.0);

    Widget circle;
    Color labelColor;
    if (stage.isCompleted) {
      circle = _badgedCircle(
        diameter: _diameter,
        fill: colors.surface,
        border: Border.all(color: AppPalette.mutedGold, width: 3),
        glyphColor: AppPalette.mutedGold,
        badgeColor: AppPalette.mutedGold,
        badgeIcon: Icons.check_rounded,
        badgeIconColor: colors.surface,
      );
      labelColor = colors.onSurface;
    } else if (stage.state == 'current') {
      circle = _currentCircle(colors: colors, pct: pct);
      if (pulseScale != null) {
        circle = ScaleTransition(scale: pulseScale!, child: circle);
      }
      labelColor = colors.primary;
    } else {
      circle = _badgedCircle(
        diameter: _diameter,
        fill: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outlineVariant),
        glyphColor: colors.outline,
        badgeColor: colors.outline,
        badgeIcon: Icons.lock_rounded,
        badgeIconColor: colors.surface,
      );
      labelColor = colors.onSurfaceVariant;
    }

    final semanticsExtra = stage.isLocked
        ? (previousStageName != null ? t.campaignUnlocksAfter(previousStageName!) : '')
        : stage.state == 'current'
            ? t.campaignYouAreHere
            : '';

    return Semantics(
      button: true,
      label: '${stage.nameFor(lang)}. $semanticsExtra',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              circle,
              const SizedBox(height: 6),
              Text(
                stage.nameFor(lang),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 3),
              // Always computed fresh by the server on every fetch (see
              // campaign/repository.py:get_stages_for_user) — no client
              // caching, so this reflects admin tagging changes as soon as
              // the map next loads.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 10, color: colors.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    t.campaignQuestionCount(stage.questionCount),
                    style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              if (stage.state == 'current') ...[
                const SizedBox(height: 2),
                Text(
                  t.campaignYouAreHere.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ] else if (stage.isLocked && previousStageName != null) ...[
                const SizedBox(height: 2),
                Text(
                  t.campaignUnlocksAfter(previousStageName!),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgedCircle({
    required double diameter,
    required Color fill,
    required Border border,
    required Color glyphColor,
    required Color badgeColor,
    required IconData badgeIcon,
    required Color badgeIconColor,
  }) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: border),
            alignment: Alignment.center,
            child: Icon(icon, color: glyphColor, size: 22),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
                border: Border.all(color: fill, width: 2),
              ),
              child: Icon(badgeIcon, size: 11, color: badgeIconColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentCircle({required ColorScheme colors, required double pct}) {
    return Container(
      width: _currentOuter,
      height: _currentOuter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.32),
            blurRadius: 22,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_currentOuter, _currentOuter),
            painter: NodeProgressRingPainter(
              progress: pct,
              color: colors.primary,
              trackColor: colors.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: _ringStroke,
            ),
          ),
          Container(
            width: _currentInner,
            height: _currentInner,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colors.onPrimary, size: 16),
                const SizedBox(height: 1),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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

/// Floating card anchored near the bottom of the screen showing the current
/// stage's progress and the Play action — replaces the inline progress bar
/// + button that used to sit under that stage's card.
class _CurrentStageCard extends StatelessWidget {
  const _CurrentStageCard({required this.stage, required this.lang, required this.onPlay});

  final CampaignStage stage;
  final String lang;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final pct = stage.target == 0 ? 0.0 : (stage.progress / stage.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(color: colors.shadow.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stage.nameFor(lang),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: colors.outlineVariant.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(t.questProgress(stage.progress, stage.target),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onPlay, child: Text(t.campaignPlayStage)),
        ],
      ),
    );
  }
}
