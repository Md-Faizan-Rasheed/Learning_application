import 'package:shared_preferences/shared_preferences.dart';

/// Local, per-device tracking of "Find My Ayah" engagement: which
/// situations have ever been opened (drives the Explore tree's leaf-bloom
/// tint and the Check In tab's "already seen" badge) and the calendar date
/// of the last daily check-in (gates the once-a-day backend XP call so
/// opening five cards in a row doesn't report five check-ins). Same
/// SharedPreferences-backed singleton pattern as NamesOnWaterProgress.
class FindMyAyahProgress {
  FindMyAyahProgress._();

  static final FindMyAyahProgress instance = FindMyAyahProgress._();

  static const _visitedKey = 'find_my_ayah_visited_situations';
  static const _lastCheckInKey = 'find_my_ayah_last_checkin_date';
  static const _seenExploreHintKey = 'find_my_ayah_seen_explore_hint';

  Future<Set<String>> visitedSituationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_visitedKey) ?? const []).toSet();
  }

  /// Records [situationId] as opened. Returns true the first time this
  /// particular situation has ever been marked visited (i.e. this call
  /// grew the set), false if it was already known — the caller uses this
  /// to decide whether a discovery milestone was just crossed.
  Future<bool> markVisited(String situationId) async {
    final prefs = await SharedPreferences.getInstance();
    final visited = await visitedSituationIds();
    if (visited.contains(situationId)) return false;
    visited.add(situationId);
    await prefs.setStringList(_visitedKey, visited.toList());
    return true;
  }

  /// Whether today is the first check-in — call before marking today's
  /// date, then call [markCheckedInToday] once the backend call succeeds
  /// (or immediately for a guest with no token, so the local gate still
  /// only allows one "attempt" per day either way).
  Future<bool> isFirstCheckInToday() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastCheckInKey);
    return last != _todayKey();
  }

  Future<void> markCheckedInToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckInKey, _todayKey());
  }

  /// Whether the first-run "Tap a star to explore" hint has already been
  /// shown and dismissed — the constellation's interaction pattern is
  /// novel enough to deserve a one-time nudge, but only ever the once.
  Future<bool> hasSeenExploreHint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenExploreHintKey) ?? false;
  }

  Future<void> markExploreHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenExploreHintKey, true);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// Discovery milestones (out of the dataset's total situation count) that
/// earn a small XP bonus on top of the flat daily check-in credit — kept
/// here (not hardcoded at the call site) so both the screen and its tests
/// agree on the same thresholds.
const List<int> kFindMyAyahMilestones = [10, 20, 30, 40];

/// The "milestone weight" to report to the backend for a check-in that
/// grew [visitedCountAfter] past one of [kFindMyAyahMilestones] — 1 for an
/// ordinary check-in, a larger flat weight when a milestone was just
/// crossed. Pure function so it's directly testable without touching
/// SharedPreferences.
int findMyAyahMilestoneWeight({required int visitedCountBefore, required int visitedCountAfter}) {
  for (final milestone in kFindMyAyahMilestones) {
    if (visitedCountBefore < milestone && visitedCountAfter >= milestone) {
      return 4;
    }
  }
  return 1;
}
