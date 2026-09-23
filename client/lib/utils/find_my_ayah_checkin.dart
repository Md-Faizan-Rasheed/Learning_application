import '../api/profile_api.dart';
import '../services/find_my_ayah_progress.dart';

/// Shared "just opened a situation card" side effect for every Find My
/// Ayah screen (the root Check In/Explore tabs and the category
/// sub-tree): marks the situation visited locally, and — at most once per
/// calendar day — reports a check-in to the real XP/streak ledger when
/// [token] is present.
///
/// [grew] tells the caller whether this was the first time this
/// particular situation was ever opened (so it can update its own visited
/// set for an immediate badge/bloom without waiting on a rebuild from
/// storage). [reward] is the backend's XP/streak response — null for a
/// guest, a repeat check-in later the same day, or a failed network call
/// (best-effort: a dropped connection here shouldn't block reading the
/// card the user already has open, and simply leaves today's gate open to
/// retry on the next card).
Future<({bool grew, ActivityResult? reward})> recordFindMyAyahOpen({
  required String? token,
  required String situationId,
  required int visitedCountBefore,
}) async {
  final progress = FindMyAyahProgress.instance;
  final grew = await progress.markVisited(situationId);

  if (!await progress.isFirstCheckInToday()) {
    return (grew: grew, reward: null);
  }

  if (token == null) {
    await progress.markCheckedInToday();
    return (grew: grew, reward: null);
  }

  final visitedCountAfter = visitedCountBefore + (grew ? 1 : 0);
  final weight = findMyAyahMilestoneWeight(
    visitedCountBefore: visitedCountBefore,
    visitedCountAfter: visitedCountAfter,
  );
  try {
    final result = await ProfileApi().completeActivity(
      token,
      activity: 'find_my_ayah',
      difficulty: 'daily',
      wordsFound: weight,
      totalWords: 1,
      seconds: 0,
      hintsUsed: 0,
    );
    await progress.markCheckedInToday();
    return (grew: grew, reward: result);
  } catch (_) {
    return (grew: grew, reward: null);
  }
}
