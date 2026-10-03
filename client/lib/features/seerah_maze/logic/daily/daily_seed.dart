/// C2 — "same maze for everyone with no server": every player's device
/// derives the same seed from the same calendar date, with no network
/// round-trip at all.
library;

/// Strips the time-of-day, keeping only the calendar date — callers pass
/// `DateTime.now().toUtc()`; this never reads the clock itself, so every
/// function in this file stays a pure function of its argument.
DateTime utcDateOnly(DateTime dateTime) =>
    DateTime.utc(dateTime.year, dateTime.month, dateTime.day);

/// A small, stable integer derived purely from the calendar date — not
/// cryptographic, just deterministic and distinct enough day to day that
/// MazeGenerator produces a visibly different maze each day.
int dailySeedFor(DateTime utcDate) {
  final date = utcDateOnly(utcDate);
  return date.year * 10000 + date.month * 100 + date.day;
}

/// How long until the next daily maze unlocks — the UTC-midnight boundary
/// after [nowUtc].
Duration timeUntilNextDaily(DateTime nowUtc) {
  final today = utcDateOnly(nowUtc);
  final tomorrow = today.add(const Duration(days: 1));
  return tomorrow.difference(nowUtc);
}
