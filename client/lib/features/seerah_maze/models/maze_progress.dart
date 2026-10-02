import 'maze_mechanics.dart';

/// Local, per-device save state for Seerah Maze — the pure-data shape a
/// later persistence step wraps in a SharedPreferences-backed repository
/// (same pattern as this app's other local-progress services, e.g.
/// services/names_on_water_progress.dart). Kept UI- and storage-independent
/// here so it's trivially testable and so the storage layer can change
/// without touching this model.
class MazeProgress {
  const MazeProgress({
    this.highestUnlockedLevel = 1,
    this.starsByLevel = const {},
    this.bestTimeSecondsByLevel = const {},
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.joystickEnabled = false,
    this.fogEnabled = false,
    this.reduceMotionEnabled = false,
    this.firstPlayHintShown = false,
    this.seenMechanicTooltips = const {},
    this.collectedFactLevelIds = const {},
  });

  final int highestUnlockedLevel;

  /// levelId -> stars earned (0-3), only present once a level's been
  /// finished at least once.
  final Map<int, int> starsByLevel;

  /// levelId -> best finish time in whole seconds.
  final Map<int, int> bestTimeSecondsByLevel;

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool joystickEnabled;
  final bool fogEnabled;

  /// B2 — the app-level half of "disable via a reduce motion setting
  /// (also honor the system accessibility reduce-motion flag)"; the
  /// system half is read separately at the point of use via
  /// MediaQuery.disableAnimations, since that's live OS state, not
  /// something to persist here.
  final bool reduceMotionEnabled;

  /// Whether the one-line "Drag to guide ..." control hint has already
  /// been shown once — it only ever shows on a player's very first level.
  final bool firstPlayHintShown;

  /// A8 — which mechanics have already shown their one-time introduction,
  /// so a level the player replays (or a mechanic repeated on a later
  /// level) never explains itself twice.
  final Set<MazeMechanicTooltip> seenMechanicTooltips;

  /// B4 — levels whose collectible fact scroll has been found, for the
  /// Library screen's unlocked/locked grid and its "X/10 found" count.
  final Set<int> collectedFactLevelIds;

  MazeProgress copyWith({
    int? highestUnlockedLevel,
    Map<int, int>? starsByLevel,
    Map<int, int>? bestTimeSecondsByLevel,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? joystickEnabled,
    bool? fogEnabled,
    bool? reduceMotionEnabled,
    bool? firstPlayHintShown,
    Set<MazeMechanicTooltip>? seenMechanicTooltips,
    Set<int>? collectedFactLevelIds,
  }) {
    return MazeProgress(
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      starsByLevel: starsByLevel ?? this.starsByLevel,
      bestTimeSecondsByLevel: bestTimeSecondsByLevel ?? this.bestTimeSecondsByLevel,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      joystickEnabled: joystickEnabled ?? this.joystickEnabled,
      fogEnabled: fogEnabled ?? this.fogEnabled,
      reduceMotionEnabled: reduceMotionEnabled ?? this.reduceMotionEnabled,
      firstPlayHintShown: firstPlayHintShown ?? this.firstPlayHintShown,
      seenMechanicTooltips: seenMechanicTooltips ?? this.seenMechanicTooltips,
      collectedFactLevelIds: collectedFactLevelIds ?? this.collectedFactLevelIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'highestUnlockedLevel': highestUnlockedLevel,
        'starsByLevel': starsByLevel.map((k, v) => MapEntry(k.toString(), v)),
        'bestTimeSecondsByLevel': bestTimeSecondsByLevel.map((k, v) => MapEntry(k.toString(), v)),
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'joystickEnabled': joystickEnabled,
        'fogEnabled': fogEnabled,
        'reduceMotionEnabled': reduceMotionEnabled,
        'firstPlayHintShown': firstPlayHintShown,
        'seenMechanicTooltips': seenMechanicTooltips.map((t) => t.name).toList(),
        'collectedFactLevelIds': collectedFactLevelIds.toList(),
      };

  /// Never throws: any parse failure (corrupted or unexpectedly-shaped
  /// JSON) falls back to fresh defaults rather than blocking the player
  /// from opening the feature at all.
  factory MazeProgress.fromJson(Map<String, dynamic> json) {
    try {
      return MazeProgress(
        highestUnlockedLevel: json['highestUnlockedLevel'] as int? ?? 1,
        starsByLevel: _intMapFrom(json['starsByLevel']),
        bestTimeSecondsByLevel: _intMapFrom(json['bestTimeSecondsByLevel']),
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        joystickEnabled: json['joystickEnabled'] as bool? ?? false,
        fogEnabled: json['fogEnabled'] as bool? ?? false,
        reduceMotionEnabled: json['reduceMotionEnabled'] as bool? ?? false,
        firstPlayHintShown: json['firstPlayHintShown'] as bool? ?? false,
        seenMechanicTooltips: _tooltipSetFrom(json['seenMechanicTooltips']),
        collectedFactLevelIds: _intSetFrom(json['collectedFactLevelIds']),
      );
    } catch (_) {
      return const MazeProgress();
    }
  }

  static Set<int> _intSetFrom(Object? raw) {
    if (raw is! List) return const {};
    final result = <int>{};
    for (final entry in raw) {
      if (entry is int) result.add(entry);
    }
    return result;
  }

  /// Unknown names (an older save, or a future version's new mechanic)
  /// are silently dropped rather than failing the whole parse.
  static Set<MazeMechanicTooltip> _tooltipSetFrom(Object? raw) {
    if (raw is! List) return const {};
    final result = <MazeMechanicTooltip>{};
    for (final entry in raw) {
      for (final tooltip in MazeMechanicTooltip.values) {
        if (tooltip.name == entry) {
          result.add(tooltip);
          break;
        }
      }
    }
    return result;
  }

  static Map<int, int> _intMapFrom(Object? raw) {
    if (raw is! Map) return const {};
    final result = <int, int>{};
    for (final entry in raw.entries) {
      final key = int.tryParse(entry.key.toString());
      final value = entry.value;
      if (key != null && value is int) result[key] = value;
    }
    return result;
  }
}
