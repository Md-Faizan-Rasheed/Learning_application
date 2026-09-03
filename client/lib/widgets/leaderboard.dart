import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../realtime/match_socket.dart';

/// Gold/silver/bronze gradients for the top 3 ranks — shared by this widget
/// and `screens/leaderboard_screen.dart` so both leaderboards podium-ize the
/// same way despite having different data models underneath.
const podiumGradients = [
  [Color(0xFFFFD54F), Color(0xFFFF9800)], // gold
  [Color(0xFFE0E0E0), Color(0xFFB0B0B0)], // silver
  [Color(0xFFD7A26A), Color(0xFF8D5524)], // bronze
];

const podiumMedalColors = [Color(0xFFB8860B), Color(0xFF757575), Color(0xFF6B3F1D)];

BoxDecoration podiumOrFlatDecoration({
  required int index,
  required ColorScheme colors,
  bool highlighted = false,
}) {
  if (index < podiumGradients.length) {
    final gradient = podiumGradients[index];
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradient[0].withValues(alpha: 0.30), gradient[1].withValues(alpha: 0.16)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gradient[0].withValues(alpha: 0.55), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: gradient[0].withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  return BoxDecoration(
    color: highlighted ? colors.primary.withValues(alpha: 0.10) : colors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: highlighted ? colors.primary.withValues(alpha: 0.4) : colors.outlineVariant,
    ),
  );
}

Widget podiumRankBadge(int index, {double size = 32}) {
  if (index >= podiumMedalColors.length) return const SizedBox.shrink();
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: podiumGradients[index]),
      boxShadow: [
        BoxShadow(color: podiumMedalColors[index].withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: size * 0.62),
  );
}

class Leaderboard extends StatelessWidget {
  final List<FinalStanding> standings;
  final String? highlightName;

  const Leaderboard({Key? key, required this.standings, this.highlightName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: standings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final standing = standings[index];
        final isMe = !standing.isBot && standing.name == highlightName;
        final isPodium = index < podiumGradients.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: podiumOrFlatDecoration(index: index, colors: colors, highlighted: isMe),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: isPodium
                    ? podiumRankBadge(index)
                    : Text(
                        '${standing.placement}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  standing.isBot ? t.mpBot : standing.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isMe || isPodium ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  t.mpPts(standing.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
