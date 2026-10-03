/// C3 — the player's best Endless run so far. Deliberately just one
/// number: how many rounds they cleared before the bank ran out. A
/// second "fastest" stat would need a currency to compare runs of
/// different lengths against each other, which rounds cleared already is.
class EndlessBestRun {
  const EndlessBestRun({this.bestRoundsCleared = 0});

  final int bestRoundsCleared;

  EndlessBestRun copyWith({int? bestRoundsCleared}) =>
      EndlessBestRun(bestRoundsCleared: bestRoundsCleared ?? this.bestRoundsCleared);

  Map<String, dynamic> toJson() => {'bestRoundsCleared': bestRoundsCleared};

  /// Falls back to the fresh default on any malformed shape, same
  /// never-throw discipline as every other save in this feature.
  factory EndlessBestRun.fromJson(Map<String, dynamic> json) {
    final rounds = json['bestRoundsCleared'];
    if (rounds is! int || rounds < 0) return const EndlessBestRun();
    return EndlessBestRun(bestRoundsCleared: rounds);
  }
}
