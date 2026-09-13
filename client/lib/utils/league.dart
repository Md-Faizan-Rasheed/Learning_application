import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/leaderboard.dart' show podiumColors;

/// Like [levelForXp] in level.dart, there's no backend concept of a
/// "league" — this is a coarser, purely client-side re-bucketing of the
/// same total_xp number into 5 tiers, for the leaderboard's visual framing.
enum League { bronze, silver, gold, diamond, master }

class LeagueInfo {
  const LeagueInfo({
    required this.league,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.xpIntoLeague,
  });

  final League league;
  final int currentThreshold;
  final int? nextThreshold;
  final int xpIntoLeague;

  double get progress {
    if (nextThreshold == null) return 1.0;
    final span = nextThreshold! - currentThreshold;
    if (span <= 0) return 1.0;
    return (xpIntoLeague / span).clamp(0.0, 1.0);
  }

  int? get xpToNext => nextThreshold == null ? null : nextThreshold! - (currentThreshold + xpIntoLeague);

  String name(AppLocalizations t) => switch (league) {
        League.bronze => t.leagueBronze,
        League.silver => t.leagueSilver,
        League.gold => t.leagueGold,
        League.diamond => t.leagueDiamond,
        League.master => t.leagueMaster,
      };

  IconData get icon => switch (league) {
        League.bronze => Icons.shield_rounded,
        League.silver => Icons.military_tech_rounded,
        League.gold => Icons.emoji_events_rounded,
        League.diamond => Icons.diamond_rounded,
        League.master => Icons.auto_awesome_rounded,
      };

  /// Flat tones climbing the same podium bronze/silver/gold ladder used
  /// elsewhere, then extending it with teal for the two tiers above gold —
  /// master (the top tier) pairs both accent colors, which the app's rules
  /// allow as a two-tone teal/gold treatment.
  List<Color> get colors => switch (league) {
        League.bronze => [podiumColors[2], podiumColors[2]],
        League.silver => [podiumColors[1], podiumColors[1]],
        League.gold => [podiumColors[0], podiumColors[0]],
        League.diamond => const [AppPalette.deepTeal, AppPalette.deepTeal],
        League.master => const [AppPalette.deepTeal, AppPalette.mutedGold],
      };
}

const _kLeagueThresholds = <int>[0, 300, 1000, 2500, 6000];
const _kLeagues = League.values;

LeagueInfo leagueForXp(int totalXp) {
  var index = 0;
  for (var i = 0; i < _kLeagueThresholds.length; i++) {
    if (totalXp >= _kLeagueThresholds[i]) {
      index = i;
    } else {
      break;
    }
  }

  final currentThreshold = _kLeagueThresholds[index];
  final isMax = index == _kLeagueThresholds.length - 1;
  final nextThreshold = isMax ? null : _kLeagueThresholds[index + 1];

  return LeagueInfo(
    league: _kLeagues[index],
    currentThreshold: currentThreshold,
    nextThreshold: nextThreshold,
    xpIntoLeague: totalXp - currentThreshold,
  );
}
