import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../services/names_on_water_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/pad_scatter.dart';
import '../utils/word_bank_entry.dart';
import '../widgets/app_header.dart';
import '../widgets/floating_pad.dart';
import '../widgets/loading_view.dart';
import '../widgets/session_complete_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/water_surface_painter.dart';

/// "Names of Allah": 5-7 names float on a themed water surface;
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
        // One flat fill from the app's own teal — matches the water panel
        // below instead of the shared teal->gold header gradient, which
        // reads as an unrelated hue here. Gold is reserved for the single
        // small accent below (the timer text), not a background.
        backgroundColor: AppPalette.deepTeal,
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
            ? LoadingView(message: t.namesOnWaterPreparing, icon: Icons.waves_rounded)
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
                  Icon(Icons.waves_rounded, size: 16, color: AppPalette.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.namesOnWaterDockHint,
                        style: TextStyle(fontSize: 12.5, color: AppPalette.inkMuted)),
                  ),
                  // The one deliberate small gold accent on this screen —
                  // everywhere else gold stays reserved for "correct".
                  Text(_formatSeconds(_elapsedSeconds),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: AppPalette.mutedGold)),
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
              child: _buildDock(t),
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
                final count = _floating.length;
                final padSize = padSizeFor(count, area);
                final floatRange = (area.height * 0.035).clamp(6.0, 14.0);
                // Deterministic per (count, area) so re-layouts (rotation,
                // resize) don't jitter the arrangement between builds.
                final anchors = scatterAnchors(
                  count: count,
                  area: area,
                  padSize: padSize,
                  seed: count * 97 + area.width.round(),
                );

                return Stack(
                  children: [
                    for (var i = 0; i < _floating.length; i++)
                      _positionedPad(
                        entry: _floating[i],
                        anchor: anchors[i],
                        padSize: padSize,
                        floatRange: floatRange,
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
    required Offset anchor,
    required double padSize,
    required double floatRange,
    required bool reduceMotion,
  }) {
    return AnimatedPositioned(
      key: ValueKey(entry.word),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      left: anchor.dx - padSize / 2,
      top: anchor.dy - padSize / 2,
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

  /// Always a two-column chip grid — sized and styled like the floating
  /// cards (same radius/border/shadow language) so the dock reads as "the
  /// same kind of object, anchored" rather than a settings-style form list.
  Widget _buildDock(AppLocalizations t) {
    const spacing = 10.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chipWidth = (constraints.maxWidth - spacing) / 2;
          return SingleChildScrollView(
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final entry in _dockOrder)
                  SizedBox(
                    width: chipWidth,
                    child: _DockSlot(
                      entry: entry,
                      filled: _matchedWords.contains(entry.word),
                      onAccept: _handleCorrectMatch,
                    ),
                  ),
              ],
            ),
          );
        },
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

/// A meaning slot in the dock — the same card-stock look (radius, border,
/// shadow) as the floating cards above it: a hairline border while
/// waiting, and a gold-tinted fill (with the same 1.0->1.03->1.0/400ms
/// settle bump option_tile.dart uses for a correct answer, plus a brief
/// expanding-ring "ripple") once a name lands on it correctly.
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
    // Same radius/border/shadow language as FloatingPad's card, whether
    // filled or not, so the dock reads as the same kind of object as the
    // floating cards rather than a disconnected settings-style list.
    const radius = 12.0;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                AppPalette.correctGold.withValues(alpha: 0.20), AppPalette.cardStock),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppPalette.correctGold, width: 1.4),
            boxShadow: [
              BoxShadow(color: AppPalette.shadowInk, blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The one icon on this screen that communicates match-state
              // rather than decorating — kept for exactly that reason.
              const Icon(Icons.check_circle_rounded, color: AppPalette.correctGold, size: 18),
              const SizedBox(height: 3),
              Text(
                widget.entry.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                _meaning,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppPalette.inkMuted, fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.cardStock,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: matching ? AppPalette.deepTeal : AppPalette.borderTaupe,
              width: matching ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(color: AppPalette.shadowInk, blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _meaning,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppPalette.ink),
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
