import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../services/names_on_water_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/name_drag_payload.dart';
import '../utils/names_of_allah_insights.dart';
import '../utils/pad_scatter.dart';
import '../utils/word_bank_entry.dart';
import '../widgets/app_header.dart';
import '../widgets/card_stock.dart';
import '../widgets/floating_name_card.dart';
import '../widgets/loading_view.dart';
import '../widgets/mark_painters.dart';
import '../widgets/medal_painter.dart';
import '../widgets/status_pill.dart';
import '../widgets/water_scenery_painter.dart';
import '../widgets/water_surface_painter.dart';

/// "Names of Allah": drag every name from the pool onto a meaning box — any
/// box accepts any name, names can be reshuffled freely before submitting,
/// and Submit only unlocks once every box is filled. Submitting reveals a
/// full, scrollable results report: right/wrong per pairing, the correct
/// pairing shown next to a wrong guess, and a genuine 3-4 line reflection on
/// every name either way (see `names_of_allah_insights.dart`).
///
/// Cycles sequentially through all 99 names across sessions (see
/// NamesOnWaterProgress) and reports completion through the same
/// /me/activity/complete hook Word Search uses.
class NamesOnWaterScreen extends StatefulWidget {
  const NamesOnWaterScreen({super.key, this.token, this.chapterIndex});

  /// When set (logged in), a completed round is reported for real XP/streak
  /// credit, same as Word Search. Null (guest play) just skips that report.
  final String? token;

  /// When set, the round plays that fixed 9-name chapter instead of the
  /// sequential auto-progress batch, and completion marks the chapter done
  /// instead of advancing the sequential pointer. Null (the default) is
  /// today's exact "Continue My Journey" behavior, unchanged.
  final int? chapterIndex;

  @override
  State<NamesOnWaterScreen> createState() => _NamesOnWaterScreenState();
}

enum _Phase { loading, playing, report }

/// One box's ground truth (which name it's meant to hold) plus whatever the
/// player actually dropped there by the time they hit Submit.
class _MatchOutcome {
  const _MatchOutcome({required this.correctEntry, required this.userEntry});
  final WordEntry correctEntry;
  final WordEntry userEntry;
  bool get isCorrect => correctEntry.word == userEntry.word;
}

String _meaningTextOf(WordEntry entry) => entry.fact.split(' — ').first;

class _NamesOnWaterScreenState extends State<NamesOnWaterScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.loading;

  /// Fixed once per round: box i's correct answer is `_boxOrder[i]`.
  List<WordEntry> _boxOrder = [];
  List<WordEntry> _pool = [];
  final Map<int, WordEntry> _placed = {};
  List<_MatchOutcome>? _outcomes;

  /// Bumped whenever the pool's card count changes — nudges every
  /// remaining [FloatingNameCard]'s drift slightly so they don't all look
  /// identically tuned after one is dragged out or back in.
  int _reflowNonce = 0;

  int _elapsedSeconds = 0;
  Timer? _ticker;

  bool _reported = false;
  ActivityResult? _activityResult;

  late final ConfettiController _confetti;

  /// Drives the slow reed-grass sway in the pool's water scenery. Purely
  /// decorative — never touched by game state.
  late final AnimationController _sceneryController;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    // Always ticking (the CustomPaint it drives is cheap); `_buildPool`
    // freezes its visible sway to zero when the platform requests reduced
    // motion, read reactively from MediaQuery at build time instead.
    _sceneryController = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..repeat();
    _loadRound();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _confetti.dispose();
    _sceneryController.dispose();
    super.dispose();
  }

  bool get _allPlaced => _placed.length == _boxOrder.length && _boxOrder.isNotEmpty;

  Future<void> _loadRound() async {
    final chapterIndex = widget.chapterIndex;
    final batch = chapterIndex != null
        ? NamesOnWaterProgress.instance.batchForChapter(chapterIndex)
        : await NamesOnWaterProgress.instance.nextBatch();
    if (!mounted) return;
    setState(() {
      _boxOrder = [...batch]..shuffle();
      _pool = [...batch]..shuffle();
      _placed.clear();
      _outcomes = null;
      _reflowNonce = 0;
      _elapsedSeconds = 0;
      _phase = _Phase.playing;
      _reported = false;
      _activityResult = null;
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
    setState(() => _phase = _Phase.loading);
    _loadRound();
  }

  void _handleDrop(NameDragPayload payload, int destBoxIndex) {
    if (payload.sourceBox == destBoxIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      final incoming = payload.entry;
      final displaced = _placed[destBoxIndex];
      if (payload.sourceBox == null) {
        _pool.removeWhere((e) => e.word == incoming.word);
      } else {
        _placed.remove(payload.sourceBox);
      }
      _placed[destBoxIndex] = incoming;
      if (displaced != null) {
        if (payload.sourceBox == null) {
          _pool.add(displaced);
        } else {
          _placed[payload.sourceBox!] = displaced;
        }
      }
      _reflowNonce++;
    });
  }

  void _returnToPool(NameDragPayload payload) {
    if (payload.sourceBox == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _placed.remove(payload.sourceBox);
      _pool.add(payload.entry);
      _reflowNonce++;
    });
  }

  void _handleSubmit() {
    if (!_allPlaced) return;
    final outcomes = [
      for (var i = 0; i < _boxOrder.length; i++)
        _MatchOutcome(correctEntry: _boxOrder[i], userEntry: _placed[i]!),
    ];
    final correct = outcomes.where((o) => o.isCorrect).length;
    final incorrect = outcomes.length - correct;
    final ratio = outcomes.isEmpty ? 0.0 : correct / outcomes.length;

    _ticker?.cancel();
    HapticFeedback.mediumImpact();
    if (ratio >= 0.6) {
      SoundService.instance.playCorrect();
      _confetti.play();
    } else {
      SoundService.instance.playIncorrect();
    }

    setState(() {
      _outcomes = outcomes;
      _phase = _Phase.report;
    });
    _finishRound(correct: correct, incorrect: incorrect);
  }

  Future<void> _finishRound({required int correct, required int incorrect}) async {
    final chapterIndex = widget.chapterIndex;
    if (chapterIndex != null) {
      await NamesOnWaterProgress.instance.markChapterComplete(chapterIndex);
    } else {
      await NamesOnWaterProgress.instance.advance(_boxOrder.length);
    }
    if (!_reported) {
      _reported = true;
      await _reportActivity(correct: correct, incorrect: incorrect);
    }
  }

  /// Reuses the exact same gamification hook Word Search reports through —
  /// one new activity type on the backend, no client API changes. `correct`
  /// maps to the backend's `matched` (clamped to total) and `incorrect`
  /// maps to its `wrong_attempts` penalty term — see
  /// `backend/app/progression/rules.py:xp_for_names_on_water`.
  Future<void> _reportActivity({required int correct, required int incorrect}) async {
    final token = widget.token;
    if (token == null) return;
    try {
      final result = await ProfileApi().completeActivity(
        token,
        activity: 'names_on_water',
        difficulty: 'standard',
        wordsFound: correct,
        totalWords: _boxOrder.length,
        seconds: _elapsedSeconds,
        hintsUsed: incorrect,
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
        child: switch (_phase) {
          _Phase.loading =>
            LoadingView(message: t.namesOnWaterPreparing, icon: Icons.mosque_rounded),
          _Phase.playing => _buildGame(t),
          _Phase.report => _buildReport(t),
        },
      ),
    );
  }

  Widget _buildGame(AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        _allPlaced ? Icons.check_circle_rounded : Icons.touch_app_rounded,
                        size: 16,
                        color: _allPlaced ? AppPalette.correctGold : AppPalette.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.chapterIndex != null
                              ? t.namesOnWaterChapterLabel(widget.chapterIndex! + 1)
                              : (_allPlaced ? t.namesOnWaterAllPlacedHint : t.namesOnWaterDockHint),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _allPlaced ? FontWeight.w700 : FontWeight.normal,
                            color: _allPlaced ? AppPalette.correctGold : AppPalette.inkMuted,
                          ),
                        ),
                      ),
                      Text(_formatSeconds(_elapsedSeconds),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13, color: AppPalette.mutedGold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPool(t, wide),
                        const SizedBox(height: 20),
                        _buildMeaningGrid(t, wide),
                      ],
                    ),
                  ),
                ),
                _buildSubmitBar(t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppPalette.ink),
        ),
      );

  /// The pool: a stretch of open water with a few rocks and reed-grass
  /// along the bottom, and every unplaced name floating on its surface,
  /// dragged the same way the old "Names on Water" screen worked. The
  /// whole panel is itself a [DragTarget], so a name dragged out of a
  /// meaning box lands back in open water instead of just disappearing.
  Widget _buildPool(AppLocalizations t, bool wide) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final poolHeight = wide ? 280.0 : 230.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(t.namesOnWaterPoolLabel),
        DragTarget<NameDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) => _returnToPool(details.data),
          builder: (context, candidates, rejected) {
            final hovering = candidates.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: poolHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hovering ? AppPalette.mutedGold : AppPalette.borderTaupe,
                  width: hovering ? 2.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: AppPalette.shadowInk, blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  color: AppPalette.deepTeal,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: WaterSurfacePainter())),
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _sceneryController,
                          builder: (context, _) => CustomPaint(
                            painter: WaterSceneryPainter(
                              swayPhase: reduceMotion ? 0 : _sceneryController.value * 2 * math.pi,
                            ),
                          ),
                        ),
                      ),
                      if (_pool.isEmpty)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppPalette.mutedGold, size: 18),
                              const SizedBox(width: 6),
                              Text(t.namesOnWaterAllPlacedHint,
                                  style: const TextStyle(
                                      color: AppPalette.mutedGold, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final area = Size(constraints.maxWidth, constraints.maxHeight);
                            final count = _pool.length;
                            final padSize = padSizeFor(count, area).clamp(56.0, 96.0);
                            final floatRange = (area.height * 0.06).clamp(6.0, 14.0);
                            // Deterministic per (count, area) so re-layouts
                            // (rotation, resize) don't jitter the arrangement
                            // between builds — kept clear of the bottom strip
                            // where the rocks/grass sit.
                            final scatterArea = Size(area.width, area.height * 0.72);
                            final anchors = scatterAnchors(
                              count: count,
                              area: scatterArea,
                              padSize: padSize,
                              seed: count * 97 + area.width.round(),
                            );
                            return Stack(
                              children: [
                                for (var i = 0; i < _pool.length; i++)
                                  AnimatedPositioned(
                                    key: ValueKey(_pool[i].word),
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    left: anchors[i].dx - padSize / 2,
                                    top: anchors[i].dy - padSize / 2,
                                    width: padSize,
                                    height: padSize,
                                    child: FloatingNameCard(
                                      entry: _pool[i],
                                      size: padSize,
                                      floatRange: floatRange,
                                      reduceMotion: reduceMotion,
                                      reflowNonce: _reflowNonce,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMeaningGrid(AppLocalizations t, bool wide) {
    final columns = wide ? 3 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(t.namesOnWaterMeaningsLabel),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final boxWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < _boxOrder.length; i++)
                  SizedBox(
                    width: boxWidth,
                    child: _MeaningBox(
                      key: ValueKey('box_$i'),
                      index: i,
                      meaningEntry: _boxOrder[i],
                      placedEntry: _placed[i],
                      onAccept: (payload) => _handleDrop(payload, i),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubmitBar(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _allPlaced ? _handleSubmit : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(t.namesOnWaterSubmitButton, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _buildReport(AppLocalizations t) {
    final outcomes = _outcomes!;
    final correct = outcomes.where((o) => o.isCorrect).length;
    final total = outcomes.length;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                children: [
                  _ResultsSummaryHeader(
                    title: t.namesOnWaterResultsTitle,
                    scoreText: t.namesOnWaterScoreSummary(correct, total),
                    timeText: _formatSeconds(_elapsedSeconds),
                    scoreLabel: t.namesOnWaterMatchedLabel,
                    timeLabel: t.wsTimeLabel,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < outcomes.length; i++) ...[
                    _ReportItemCard(index: i, outcome: outcomes[i]),
                    const SizedBox(height: 12),
                  ],
                  if (_activityResult != null) ...[
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.practicePlayAgain),
                  ),
                ],
              ),
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 26,
          gravity: 0.3,
          shouldLoop: false,
          colors: const [AppPalette.deepTeal, AppPalette.mutedGold, AppPalette.cardStock],
        ),
      ],
    );
  }
}

/// A draggable name chip sitting inside a filled meaning box — the static,
/// non-floating counterpart to [FloatingNameCard] in the pool. A card reads
/// as "the same object, moved" whichever of the two it currently is,
/// carrying the snap-in feeling of drag-and-drop across the transition.
class _NameCard extends StatelessWidget {
  const _NameCard({super.key, required this.entry, required this.sourceBox});

  final WordEntry entry;

  /// null = this card currently lives in the pool; otherwise the index of
  /// the meaning box it's currently sitting in.
  final int? sourceBox;

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: cardStockDecoration(borderRadius: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              entry.arabicScript,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppPalette.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppPalette.inkMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = NameDragPayload(entry: entry, sourceBox: sourceBox);
    return Draggable<NameDragPayload>(
      data: payload,
      onDragStarted: () => HapticFeedback.selectionClick(),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.08, child: _chip()),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _chip()),
      child: _chip(),
    );
  }
}

/// The bump used when a name lands in (or is swapped inside) a meaning box —
/// deliberately neutral (no gold/red tint, no ripple) since correctness is
/// unknown until Submit; only the report screen's cards get the gold/red
/// correct/incorrect treatment.
final _boxBumpTween = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 65),
]);

/// A meaning box — always shows the meaning it represents, and always
/// accepts any dragged name (there is deliberately no "wrong answer
/// rejected" path here; that check only happens once, at Submit).
class _MeaningBox extends StatefulWidget {
  const _MeaningBox({
    super.key,
    required this.index,
    required this.meaningEntry,
    required this.placedEntry,
    required this.onAccept,
  });

  final int index;
  final WordEntry meaningEntry;
  final WordEntry? placedEntry;
  final ValueChanged<NameDragPayload> onAccept;

  @override
  State<_MeaningBox> createState() => _MeaningBoxState();
}

class _MeaningBoxState extends State<_MeaningBox> with SingleTickerProviderStateMixin {
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    if (widget.placedEntry != null) _settle.value = 1;
  }

  @override
  void didUpdateWidget(covariant _MeaningBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEmpty = oldWidget.placedEntry == null;
    final isEmpty = widget.placedEntry == null;
    if (wasEmpty && !isEmpty) {
      _settle.forward(from: 0);
    } else if (!wasEmpty && isEmpty) {
      _settle.value = 0;
    } else if (oldWidget.placedEntry?.word != widget.placedEntry?.word) {
      // Swapped to a different card while staying filled — a smaller re-bump.
      _settle.forward(from: 0.4);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.placedEntry != null;
    return DragTarget<NameDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => widget.onAccept(details.data),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return AnimatedBuilder(
          animation: _settle,
          builder: (context, child) {
            final bump = _boxBumpTween.evaluate(_settle);
            return Transform.scale(scale: 1.0 + bump * 0.025, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: filled
                  ? Color.alphaBlend(AppPalette.deepTeal.withValues(alpha: 0.14), AppPalette.cardStock)
                  : AppPalette.cardStock,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hovering
                    ? AppPalette.deepTeal
                    : (filled ? AppPalette.deepTeal.withValues(alpha: 0.55) : AppPalette.borderTaupe),
                width: hovering ? 1.8 : (filled ? 1.4 : 1),
              ),
              boxShadow: [
                BoxShadow(color: AppPalette.shadowInk, blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _meaningTextOf(widget.meaningEntry),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12.5, color: AppPalette.ink),
                ),
                const SizedBox(height: 8),
                if (filled)
                  _NameCard(
                    key: ValueKey('placed_${widget.placedEntry!.word}'),
                    entry: widget.placedEntry!,
                    sourceBox: widget.index,
                  )
                else
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.borderTaupe),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.add_rounded, color: AppPalette.inkMuted, size: 18),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The trophy-style header at the top of the results report — same visual
/// language as [SessionCompleteCard] (colors.primary panel, [MedalIcon],
/// stat row), rebuilt locally so it composes cleanly inside this screen's
/// own scrollable results list instead of nesting two scroll views.
class _ResultsSummaryHeader extends StatelessWidget {
  const _ResultsSummaryHeader({
    required this.title,
    required this.scoreText,
    required this.timeText,
    required this.scoreLabel,
    required this.timeLabel,
  });

  final String title;
  final String scoreText;
  final String timeText;
  final String scoreLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colors.primary,
        boxShadow: [
          BoxShadow(color: AppPalette.shadowInk, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          const MedalIcon(size: 52),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HeaderStat(value: scoreText, label: scoreLabel, onPrimary: colors.onPrimary),
              _HeaderStat(value: timeText, label: timeLabel, onPrimary: colors.onPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label, required this.onPrimary});
  final String value;
  final String label;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: onPrimary, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: onPrimary.withValues(alpha: 0.85), fontSize: 12),
        ),
      ],
    );
  }
}

/// One name's full breakdown in the results report: correct/incorrect mark,
/// the name itself, the user's answer vs. the correct one when they got it
/// wrong, and — for every name regardless of outcome — the genuine 3-4 line
/// reflection from `names_of_allah_insights.dart`. Fades and rises in with a
/// small per-index stagger, the same entrance vocabulary `OptionTile` uses
/// elsewhere in the app, so a cascade of cards reads as one connected reveal
/// rather than a static list appearing all at once.
class _ReportItemCard extends StatefulWidget {
  const _ReportItemCard({required this.index, required this.outcome});
  final int index;
  final _MatchOutcome outcome;

  @override
  State<_ReportItemCard> createState() => _ReportItemCardState();
}

class _ReportItemCardState extends State<_ReportItemCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    Future.delayed(Duration(milliseconds: widget.index * 70), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) _entrance.value = 1;
    final t = AppLocalizations.of(context)!;
    final o = widget.outcome;
    final color = o.isCorrect ? AppPalette.correctGold : AppPalette.incorrectRed;
    // Guaranteed present by names_of_allah_insights_test.dart's completeness
    // check — every kNamesOfAllah entry has exactly one insight.
    final insight = kNameInsights[o.correctEntry.word]!;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_entrance.value);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.10), AppPalette.cardStock),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
          boxShadow: [
            BoxShadow(color: AppPalette.shadowInk, blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: o.isCorrect
                        ? const CheckmarkPainter(color: AppPalette.correctGold)
                        : const CrossPainter(color: AppPalette.incorrectRed),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          o.correctEntry.arabicScript,
                          style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic', fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      Text(
                        o.correctEntry.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
                Text(
                  o.isCorrect ? t.namesOnWaterCorrectBadge : t.namesOnWaterIncorrectBadge,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!o.isCorrect) ...[
              _AnswerLine(
                label: t.namesOnWaterYourAnswerLabel,
                text: _meaningTextOf(o.userEntry),
                color: AppPalette.incorrectRed,
                strikethrough: true,
              ),
              const SizedBox(height: 6),
            ],
            _AnswerLine(
              label: t.namesOnWaterCorrectAnswerLabel,
              text: _meaningTextOf(o.correctEntry),
              color: AppPalette.correctGold,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppPalette.borderTaupe),
            const SizedBox(height: 12),
            Text(
              insight,
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppPalette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.text,
    required this.color,
    this.strikethrough = false,
  });

  final String label;
  final String text;
  final Color color;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12.5),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: AppPalette.inkMuted, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              decorationColor: color,
            ),
          ),
        ],
      ),
    );
  }
}
