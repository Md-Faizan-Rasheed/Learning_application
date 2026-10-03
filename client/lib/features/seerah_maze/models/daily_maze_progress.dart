/// C2 — persisted state for the Daily Maze mode: the current/best streak,
/// the last UTC calendar date actually counted, and a bounded history of
/// played dates for the calendar view. Kept separate from [MazeProgress]
/// (the 10-level campaign's save) since this is a wholly different mode
/// with its own independent streak, not a per-level field.
class DailyMazeProgress {
  const DailyMazeProgress({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCountedUtcDate,
    this.playedUtcDates = const {},
  });

  final int currentStreak;
  final int bestStreak;

  /// The UTC calendar date (time-of-day always midnight) whose play last
  /// actually advanced the streak — null before the player's first-ever
  /// daily completion.
  final DateTime? lastCountedUtcDate;

  /// Every UTC calendar date the daily maze was completed on, for the
  /// calendar-style history — see [DailyMazeProgress.withHistoryTrimmed]
  /// for why this never grows unbounded.
  final Set<DateTime> playedUtcDates;

  static const int _historyLimitDays = 120;

  DailyMazeProgress copyWith({
    int? currentStreak,
    int? bestStreak,
    DateTime? lastCountedUtcDate,
    Set<DateTime>? playedUtcDates,
  }) {
    return DailyMazeProgress(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCountedUtcDate: lastCountedUtcDate ?? this.lastCountedUtcDate,
      playedUtcDates: playedUtcDates ?? this.playedUtcDates,
    );
  }

  /// Keeps only the most recent [_historyLimitDays] dates — a calendar
  /// view never needs more than a few months back, and an uncapped set
  /// would otherwise grow forever over years of daily play.
  DailyMazeProgress withHistoryTrimmed(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(const Duration(days: _historyLimitDays));
    final trimmed = playedUtcDates.where((d) => d.isAfter(cutoff)).toSet();
    if (trimmed.length == playedUtcDates.length) return this;
    return copyWith(playedUtcDates: trimmed);
  }

  static String _dateToKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Rejects anything DateTime.utc would otherwise silently *normalize*
  /// — it rolls an out-of-range month/day arithmetic-overflow style
  /// (e.g. month 13 becomes next January) rather than throwing, which
  /// would let a corrupted stored date quietly become a different, real
  /// date instead of being caught as invalid.
  static DateTime? _dateFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12) return null;
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) return null;
    return DateTime.utc(year, month, day);
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastCountedUtcDate': lastCountedUtcDate == null ? null : _dateToKey(lastCountedUtcDate!),
        'playedUtcDates': playedUtcDates.map(_dateToKey).toList(),
      };

  /// Never throws: any malformed shape falls back to fresh defaults,
  /// matching every other save in this feature.
  factory DailyMazeProgress.fromJson(Map<String, dynamic> json) {
    try {
      final lastCountedRaw = json['lastCountedUtcDate'];
      return DailyMazeProgress(
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        lastCountedUtcDate: lastCountedRaw is String ? _dateFromKey(lastCountedRaw) : null,
        playedUtcDates: _datesFrom(json['playedUtcDates']),
      );
    } catch (_) {
      return const DailyMazeProgress();
    }
  }

  static Set<DateTime> _datesFrom(Object? raw) {
    if (raw is! List) return const {};
    final result = <DateTime>{};
    for (final entry in raw) {
      if (entry is! String) continue;
      final date = _dateFromKey(entry);
      if (date != null) result.add(date);
    }
    return result;
  }
}
