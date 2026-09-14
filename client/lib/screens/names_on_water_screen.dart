import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../services/names_on_water_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/word_bank_entry.dart';
import '../widgets/app_header.dart';
import '../widgets/floating_pad.dart';
import '../widgets/loading_view.dart';
import '../widgets/session_complete_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/water_surface_painter.dart';

/// "Names on Water": 5-7 Names of Allah float on a themed water surface;
/// the player drags each onto its matching meaning in the dock below.
/// Cycles sequentially through all 99 names across sessions (see
/// NamesOnWaterProgress) and reports completion through the same
/// /me/activity/complete hook Word Search uses.
class NamesOnWaterScreen extends StatefulWidget {
  const NamesOnWaterScreen({super.key, this.token});

  /// When set (logged in), a completed round is reported for real XP/streak
  /// credit, same as Word Search. Null (guest play) just skips that report.
  final String? token;

  @override
  State<NamesOnWaterScreen> createState() => _NamesOnWaterScreenState();
}

class _NamesOnWaterScreenState extends State<NamesOnWaterScreen> {
  bool _loading = true;
  bool _complete = false;

  List<WordEntry> _floating = [];
  List<WordEntry> _dockOrder = [];
  final Set<String> _matchedWords = {};
  int _wrongAttempts = 0;
  int _reflowNonce = 0;

  int _elapsedSeconds = 0;
  Timer? _ticker;

  bool _reported = false;
  ActivityResult? _activityResult;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadRound() async {
    final batch = await NamesOnWaterProgress.instance.nextBatch();
    if (!mounted) return;
    setState(() {
      _floating = [...batch];
      _dockOrder = [...batch]..shuffle();
      _matchedWords.clear();
      _wrongAttempts = 0;
      _reflowNonce = 0;
      _elapsedSeconds = 0;
      _complete = false;
      _reported = false;
      _activityResult = null;
      _loading = false;
    });
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _restart() {
    _ticker?.cancel();
    setState(() => _loading = true);
    _loadRound();
  }

  void _handleCorrectMatch(WordEntry entry) {
    SoundService.instance.playCorrect();
    HapticFeedback.lightImpact();
    setState(() {
      _matchedWords.add(entry.word);
      _floating.removeWhere((e) => e.word == entry.word);
      _reflowNonce++;
    });
    if (_matchedWords.length == _dockOrder.length) {
      _finishRound();
    }
  }

  void _handleWrongDrop() {
    setState(() => _wrongAttempts++);
  }

  Future<void> _finishRound() async {
    _ticker?.cancel();
    setState(() => _complete = true);
    await NamesOnWaterProgress.instance.advance(_dockOrder.length);
    if (!_reported) {
      _reported = true;
      await _reportActivity();
    }
  }

  /// Reuses the exact same gamification hook Word Search reports through —
  /// one new activity type on the backend, no client API changes. The
  /// `difficulty` field is a required-but-unused sentinel for this activity
  /// (the shared envelope was shaped around Word Search originally).
  Future<void> _reportActivity() async {
    final token = widget.token;
    if (token == null) return;
    try {
      final result = await ProfileApi().completeActivity(
        token,
        activity: 'names_on_water',
        difficulty: 'standard',
        wordsFound: _matchedWords.length,
        totalWords: _dockOrder.length,
        seconds: _elapsedSeconds,
        hintsUsed: _wrongAttempts,
      );
      if (mounted) setState(() => _activityResult = result);
    } catch (_) {
      // Non-critical background report — same resilience as Word Search's.
    }
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.namesOnWaterScreenTitle,
        actions: [
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t.wsRestartTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? LoadingView(message: t.namesOnWaterPreparing, icon: Icons.water_rounded)
            : (_complete ? _buildComplete(t) : _buildGame(t)),
      ),
    );
  }

  Widget _buildGame(AppLocalizations t) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.swipe_rounded, size: 16, color: AppPalette.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.namesOnWaterDockHint,
                        style: TextStyle(fontSize: 12.5, color: AppPalette.inkMuted)),
                  ),
                  Text(_formatSeconds(_elapsedSeconds),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildWaterArea(reduceMotion),
              ),
            ),
            Expanded(
              flex: wide ? 1 : 2,
              child: _buildDock(t, wide),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaterArea(bool reduceMotion) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(color: AppPalette.deepTeal),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: WaterSurfacePainter())),
            LayoutBuilder(
              builder: (context, constraints) {
                final area = Size(constraints.maxWidth, constraints.maxHeight);
                final count = math.max(1, _floating.length);
                final cols = math.max(1, math.sqrt(count * area.width / area.height).ceil());
                final rows = (count / cols).ceil();
                final cellW = area.width / cols;
                final cellH = area.height / rows;
                final padSize = (math.min(cellW, cellH) * 0.72).clamp(64.0, 128.0);
                final floatRange = (area.height * 0.035).clamp(6.0, 14.0);
                // Deterministic per (count, area) so re-layouts (rotation,
                // resize) don't jitter the arrangement between builds.
                final rng = math.Random(count * 97 + area.width.round());

                return Stack(
                  children: [
                    for (var i = 0; i < _floating.length; i++)
                      _positionedPad(
                        entry: _floating[i],
                        index: i,
                        cols: cols,
                        cellW: cellW,
                        cellH: cellH,
                        padSize: padSize,
                        floatRange: floatRange,
                        area: area,
                        rng: rng,
                        reduceMotion: reduceMotion,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedPad({
    required WordEntry entry,
    required int index,
    required int cols,
    required double cellW,
    required double cellH,
    required double padSize,
    required double floatRange,
    required Size area,
    required math.Random rng,
    required bool reduceMotion,
  }) {
    final col = index % cols;
    final row = index ~/ cols;
    final cx = col * cellW + cellW / 2;
    final cy = row * cellH + cellH / 2;
    final maxJitterX = math.max(0.0, cellW / 2 - padSize / 2 - 4);
    final maxJitterY = math.max(0.0, cellH / 2 - padSize / 2 - 4);
    final jx = (rng.nextDouble() * 2 - 1) * maxJitterX;
    final jy = (rng.nextDouble() * 2 - 1) * maxJitterY;
    final anchorX = (cx + jx).clamp(padSize / 2, math.max(padSize / 2, area.width - padSize / 2));
    final anchorY =
        (cy + jy).clamp(padSize / 2, math.max(padSize / 2, area.height - padSize / 2));

    return AnimatedPositioned(
      key: ValueKey(entry.word),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      left: anchorX - padSize / 2,
      top: anchorY - padSize / 2,
      width: padSize,
      height: padSize,
      child: FloatingPad(
        entry: entry,
        size: padSize,
        floatRange: floatRange,
        reduceMotion: reduceMotion,
        reflowNonce: _reflowNonce,
        onDropResult: (accepted) {
          if (!accepted) _handleWrongDrop();
        },
      ),
    );
  }

  Widget _buildDock(AppLocalizations t, bool wide) {
    final slots = [
      for (final entry in _dockOrder)
        _DockSlot(
          entry: entry,
          filled: _matchedWords.contains(entry.word),
          onAccept: _handleCorrectMatch,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: wide
          ? SingleChildScrollView(
              child: Wrap(spacing: 10, runSpacing: 10, children: slots),
            )
          : ListView.separated(
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => slots[i],
            ),
    );
  }

  Widget _buildComplete(AppLocalizations t) {
    final card = SessionCompleteCard(
      title: t.namesOnWaterRoundComplete,
      celebrate: true,
      stats: [
        StatItem(
            value: '${_matchedWords.length}/${_dockOrder.length}',
            label: t.namesOnWaterMatchedLabel),
        StatItem(value: _formatSeconds(_elapsedSeconds), label: t.wsTimeLabel),
      ],
      buttonLabel: t.practicePlayAgain,
      onButtonPressed: _restart,
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            card,
            if (_activityResult != null) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusPill(
                    label: t.wsActivityXpEarned(_activityResult!.xpEarned),
                    tone: StatusTone.success,
                    icon: Icons.stars_rounded,
                  ),
                  if (_activityResult!.streakExtended)
                    StatusPill(
                      label: t.rewardStreakDays(_activityResult!.streakDays),
                      tone: StatusTone.warning,
                      icon: Icons.local_fire_department_rounded,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A meaning slot in the dock — mirrors SeatMarker's empty/filled
/// dichotomy: a dashed hairline outline while waiting, a gold-tinted
/// card-stock fill (with the same 1.0->1.03->1.0/400ms settle bump
/// option_tile.dart uses for a correct answer, plus a brief expanding-ring
/// "ripple") once a name lands on it correctly.
class _DockSlot extends StatefulWidget {
  const _DockSlot({required this.entry, required this.filled, required this.onAccept});

  final WordEntry entry;
  final bool filled;
  final ValueChanged<WordEntry> onAccept;

  @override
  State<_DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends State<_DockSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    if (widget.filled) _settle.value = 1;
  }

  @override
  void didUpdateWidget(_DockSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filled && !oldWidget.filled) {
      _settle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  String get _meaning => widget.entry.fact.split(' — ').first;

  @override
  Widget build(BuildContext context) {
    if (widget.filled) {
      return AnimatedBuilder(
        animation: _settle,
        builder: (context, child) {
          final bump = _bumpTween.evaluate(_settle);
          return Transform.scale(
            scale: 1.0 + bump * 0.03,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                child!,
                if (_settle.value < 1)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RippleBurstPainter(progress: _settle.value),
                    ),
                  ),
              ],
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                AppPalette.correctGold.withValues(alpha: 0.20), AppPalette.cardStock),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.correctGold, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppPalette.correctGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.entry.displayName} — $_meaning',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DragTarget<WordEntry>(
      onWillAcceptWithDetails: (details) => details.data.word == widget.entry.word,
      onAcceptWithDetails: (details) => widget.onAccept(details.data),
      builder: (context, candidates, rejected) {
        // candidates only contains data for which onWillAcceptWithDetails
        // returned true — so this only highlights when the name currently
        // being dragged is actually this slot's match, not any drag at all.
        final matching = candidates.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: matching
                ? AppPalette.deepTeal.withValues(alpha: 0.08)
                : AppPalette.cardStock.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: _DashedRectPainter(
              color: matching ? AppPalette.deepTeal : AppPalette.borderTaupe,
            ),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, size: 16, color: AppPalette.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppPalette.ink),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The exact bump shape option_tile.dart uses for a correct answer — reused
/// here so "correct" reads the same way across every part of the app.
final _bumpTween = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 65),
]);

class _RippleBurstPainter extends CustomPainter {
  const _RippleBurstPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppPalette.mutedGold.withValues(alpha: (0.35 * (1 - progress)).clamp(0.0, 1.0));
    canvas.drawCircle(center, maxRadius * progress, paint);
  }

  @override
  bool shouldRepaint(covariant _RippleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      const dashLength = 5.0;
      const gapLength = 4.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
