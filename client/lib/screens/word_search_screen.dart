import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../l10n/app_localizations.dart';
import '../services/word_search_stats.dart';
import '../theme/app_theme.dart';
import '../utils/word_search_generator.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/card_stock.dart';
import '../widgets/session_complete_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/word_search_grid.dart';

const _kMaxHints = 3;
const _kPointsPerWord = 10;
const _kHintPenalty = 5;
const _kMaxHintTier = 3;

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({
    super.key,
    required this.difficulty,
    this.category = WordSearchCategory.prophets,
    this.clueMode = false,
    this.token,
  });

  final WordSearchDifficulty difficulty;
  final WordSearchCategory category;

  /// When true, an unfound word's sidebar chip shows its fact/clue instead
  /// of the plain word itself — the player has to recall which word the
  /// clue points to before searching for it, rather than just letter
  /// -matching a word they can already read. Grid letters are unaffected
  /// either way; this only changes what the sidebar gives away up front.
  final bool clueMode;

  /// When set (the player is logged in), a completed puzzle is reported to
  /// the same profile ledger a finished multiplayer match updates — real,
  /// persisted XP and streak credit, not just the local best-time blob.
  /// Null (guest play) skips that report entirely; the puzzle still works
  /// exactly as it always has.
  final String? token;

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  late WordSearchPuzzle _puzzle;
  final Set<PlacedWord> _foundWords = {};
  Set<GridPos> _hintCells = {};
  Timer? _hintClearTimer;

  int _elapsedSeconds = 0;
  Timer? _ticker;
  int _score = 0;
  int _hintsUsed = 0;

  // The hint budget escalates on whichever word it's currently pointed at,
  // rather than spending each press on a fresh random word: tier 1 reveals
  // just the first cell, tier 2 the first two (showing direction), tier 3
  // the full path. Pressing hint again after a target is found (by the
  // player or by the hint itself) starts a new target back at tier 1.
  PlacedWord? _hintTarget;
  int _hintTier = 0;

  bool _complete = false;
  bool _statsSaved = false;
  ActivityResult? _activityResult;

  @override
  void initState() {
    super.initState();
    _puzzle = generatePuzzleForDifficulty(widget.difficulty, category: widget.category);
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hintClearTimer?.cancel();
    super.dispose();
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
    _hintClearTimer?.cancel();
    setState(() {
      _puzzle = generatePuzzleForDifficulty(widget.difficulty, category: widget.category);
      _foundWords.clear();
      _hintCells = {};
      _elapsedSeconds = 0;
      _score = 0;
      _hintsUsed = 0;
      _hintTarget = null;
      _hintTier = 0;
      _complete = false;
      _statsSaved = false;
      _activityResult = null;
    });
    _startTicker();
  }

  void _onWordFound(PlacedWord found) {
    setState(() {
      _foundWords.add(found);
      _score += _kPointsPerWord;
    });
    if (_foundWords.length >= _puzzle.placedWords.length) {
      _finish();
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    // Faster finishes earn a bonus, capped so it can't dominate the score.
    final timeBonus = max(0, 120 - _elapsedSeconds);
    setState(() {
      _complete = true;
      _score += timeBonus;
    });
    if (!_statsSaved) {
      _statsSaved = true;
      await WordSearchStats.instance.recordCompletion(
          widget.category, widget.difficulty,
          seconds: _elapsedSeconds);
      await _reportActivity();
    }
  }

  /// Reports the finished puzzle to the real profile (XP + streak), same
  /// ledger a finished multiplayer match updates. Guest play (no token)
  /// skips this entirely — that path is unchanged from before. A network
  /// failure here is swallowed rather than shown: the puzzle is already
  /// done and the local stats already saved, so this is a bonus on top,
  /// not something worth surfacing an error banner over.
  Future<void> _reportActivity() async {
    final token = widget.token;
    if (token == null) return;
    try {
      final result = await ProfileApi().completeActivity(
        token,
        activity: 'word_search',
        category: widget.category.name,
        difficulty: widget.difficulty.name,
        wordsFound: _foundWords.length,
        totalWords: _puzzle.placedWords.length,
        seconds: _elapsedSeconds,
        hintsUsed: _hintsUsed,
        words: _foundWords.map((w) => w.word.word).toList(),
      );
      if (mounted) setState(() => _activityResult = result);
    } catch (_) {
      // Non-critical background report — see doc comment above.
    }
  }

  void _useHint() {
    if (_hintsUsed >= _kMaxHints) return;
    final remaining =
        _puzzle.placedWords.where((w) => !_foundWords.contains(w)).toList();
    if (remaining.isEmpty) return;

    // Keep escalating the same target across consecutive presses; only
    // pick a fresh one if there isn't a live target (first hint ever, or
    // the previous target got found some other way).
    final previousTarget = _hintTarget;
    final freshTarget = previousTarget == null || !remaining.contains(previousTarget);
    final PlacedWord target =
        freshTarget ? remaining[Random().nextInt(remaining.length)] : previousTarget;
    final tier = min((freshTarget ? 0 : _hintTier) + 1, _kMaxHintTier);
    final revealCount = switch (tier) {
      1 => 1,
      2 => 2,
      _ => target.cells.length,
    };

    _hintClearTimer?.cancel();
    setState(() {
      _hintsUsed++;
      _score = max(0, _score - _kHintPenalty);
      _hintTarget = target;
      _hintTier = tier;
      _hintCells = target.cells.take(revealCount).toSet();
    });
    // A single revealed cell is easy to miss — give the earlier, weaker
    // tiers a bit longer on screen than the full-path reveal.
    final flashMs = tier >= _kMaxHintTier ? 1200 : 1800;
    _hintClearTimer = Timer(Duration(milliseconds: flashMs), () {
      if (mounted) setState(() => _hintCells = {});
    });
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
        title: t.wsScreenTitle,
        actions: [
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t.wsRestartTooltip,
          ),
        ],
      ),
      body: ScreenWithAmbientBackdrop(
        child: SafeArea(
          child: _complete ? _buildComplete(t) : _buildGame(t),
        ),
      ),
    );
  }

  Widget _buildComplete(AppLocalizations t) {
    final card = SessionCompleteCard(
      title: t.wsPuzzleComplete,
      celebrate: true,
      stats: [
        StatItem(
            value: '${_foundWords.length}/${_puzzle.placedWords.length}',
            label: t.wsFoundLabel),
        StatItem(
            value: _formatSeconds(_elapsedSeconds), label: t.wsTimeLabel),
        StatItem(value: '+$_score', label: t.wsScoreLabel),
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
              _buildActivityResultBadge(t, _activityResult!),
            ],
            const SizedBox(height: 16),
            _buildWordsLearnedRecap(t),
          ],
        ),
      ),
    );
  }

  /// Only shown once the backend has actually confirmed the XP/streak
  /// report (see _reportActivity) — guests and offline failures simply
  /// never see this, rather than showing a number that might not be real.
  Widget _buildActivityResultBadge(AppLocalizations t, ActivityResult result) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        StatusPill(
          label: t.wsActivityXpEarned(result.xpEarned),
          tone: StatusTone.success,
          icon: Icons.stars_rounded,
        ),
        if (result.streakExtended)
          StatusPill(
            label: t.rewardStreakDays(result.streakDays),
            tone: StatusTone.warning,
            icon: Icons.local_fire_department_rounded,
          ),
      ],
    );
  }

  /// A reviewable recap of every fact surfaced during the puzzle — the
  /// "fact toast" each word triggered on find is transient, so this is the
  /// one place a player can go back and re-read all of them at once.
  Widget _buildWordsLearnedRecap(AppLocalizations t) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: CardStock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.wsWordsLearnedTitle,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 10),
              for (final placed in _puzzle.placedWords) ...[
                Text(
                  '${placed.word.word} — ${placed.word.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  placed.word.fact,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppPalette.inkMuted,
                  ),
                ),
                if (placed != _puzzle.placedWords.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final horizontalPadding = constraints.maxWidth >= 900
            ? 0.0
            : (constraints.maxWidth >= 600 ? 32.0 : 16.0);

        final header = _buildStatusBar(t);
        final wordList = _buildWordList(t);
        final grid = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: WordSearchGrid(
            puzzle: _puzzle,
            foundWords: _foundWords,
            hintCells: _hintCells,
            onWordFound: _onWordFound,
          ),
        );

        return Padding(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 16),
          child: wide
              ? Column(
                  children: [
                    header,
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 220, child: wordList),
                          const SizedBox(width: 16),
                          Expanded(child: grid),
                        ],
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      grid,
                      wordList,
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatusBar(AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(_formatSeconds(_elapsedSeconds),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          Icon(Icons.stars_rounded, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('$_score', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(
            onPressed: _hintsUsed >= _kMaxHints ? null : _useHint,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
            label: Text(t.wsHintsRemaining(_kMaxHints - _hintsUsed)),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final placed in _puzzle.placedWords)
            _WordFactChip(
              word: placed.word.word,
              displayName: placed.word.displayName,
              fact: placed.word.fact,
              found: _foundWords.contains(placed),
              clueMode: widget.clueMode,
            ),
        ],
      ),
    );
  }
}

/// A found word's chip upgrades in place from a plain unsolved pill into a
/// small fact card — tap to expand the full fact if it's been truncated.
/// Not-found words never reveal the fact, so finding one is still the payoff.
class _WordFactChip extends StatefulWidget {
  const _WordFactChip({
    required this.word,
    required this.displayName,
    required this.fact,
    required this.found,
    required this.clueMode,
  });

  final String word;
  final String displayName;
  final String fact;
  final bool found;

  /// Show the fact as a clue in place of the plain word before it's found.
  final bool clueMode;

  @override
  State<_WordFactChip> createState() => _WordFactChipState();
}

class _WordFactChipState extends State<_WordFactChip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (!widget.found) {
      if (!widget.clueMode) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Text(
            widget.word,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        );
      }

      // Clue mode: the word itself stays hidden, and its fact is shown as
      // the clue to recall from instead — tap to expand if it's truncated.
      return GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Text(
              widget.fact,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.correctGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.correctGold),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.word} · ${widget.displayName}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 3),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: Text(
                widget.fact,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppPalette.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
