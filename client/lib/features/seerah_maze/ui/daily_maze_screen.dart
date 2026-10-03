import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/streak_flame.dart';
import '../constants/maze_colors.dart';
import '../data/daily_maze_repository.dart';
import '../logic/daily/daily_seed.dart';
import '../models/daily_maze_progress.dart';
import 'daily_maze_play_screen.dart';
import 'responsive/maze_breakpoints.dart';

/// C2 — the Daily Maze's own home: streak, a calendar-style history of
/// recent days played, a countdown to the next daily, and the entry
/// point into today's puzzle.
class DailyMazeScreen extends StatefulWidget {
  const DailyMazeScreen({super.key});

  @override
  State<DailyMazeScreen> createState() => _DailyMazeScreenState();
}

class _DailyMazeScreenState extends State<DailyMazeScreen> {
  static const _repository = DailyMazeRepository();

  DailyMazeProgress _progress = const DailyMazeProgress();
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _untilNext = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _tickCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _tickCountdown() {
    if (!mounted) return;
    setState(() => _untilNext = timeUntilNextDaily(DateTime.now().toUtc()));
  }

  Future<void> _load() async {
    final loaded = await _repository.load();
    if (!mounted) return;
    setState(() {
      _progress = loaded;
      _loading = false;
    });
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DailyMazePlayScreen()),
    );
    await _load(); // the play screen saved its own progress; pick it up
  }

  bool get _playedToday {
    final today = utcDateOnly(DateTime.now().toUtc());
    final last = _progress.lastCountedUtcDate;
    return last != null && last.isAtSameMomentAs(today);
  }

  String _formatCountdown(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

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
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Column(
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
                                  t.mazeDailyTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 48), // balances the back button
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: MazeColors.boardPanel,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: StreakFlame(streak: _progress.currentStreak),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  t.mazeDailyCountdownLabel(_formatCountdown(_untilNext)),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 18),
                                _CalendarHistory(playedUtcDates: _progress.playedUtcDates),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: _play,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(
                                      _playedToday
                                          ? t.mazeDailyPracticeButton
                                          : t.mazeDailyPlayButton,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

/// A 4-week grid (28 days, oldest first, ending today) — gold-filled for
/// a day the daily maze was completed, dim otherwise, with today's cell
/// outlined so it's always identifiable regardless of locale/date format.
class _CalendarHistory extends StatelessWidget {
  const _CalendarHistory({required this.playedUtcDates});

  final Set<DateTime> playedUtcDates;

  @override
  Widget build(BuildContext context) {
    final today = utcDateOnly(DateTime.now().toUtc());
    final days = List.generate(28, (i) => today.subtract(Duration(days: 27 - i)));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final played = playedUtcDates.contains(day);
        final isToday = day.isAtSameMomentAs(today);
        return Semantics(
          label: '${day.year}-${day.month}-${day.day}${played ? ', completed' : ''}',
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: played ? AppPalette.mutedGold : MazeColors.boardPanel.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: isToday ? Border.all(color: Colors.white, width: 1.5) : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
