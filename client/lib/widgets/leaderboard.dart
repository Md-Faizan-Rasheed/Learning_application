import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../realtime/match_socket.dart';
import '../theme/app_theme.dart';
import 'medal_painter.dart';

/// Flat gold/silver/bronze tones for the top 3 ranks — shared by this widget
/// and other leaderboards (`screens/leaderboard_screen.dart`,
/// `screens/teacher/quiz_results_screen.dart`) so every podium in the app
/// uses the same three colors. No gradients: rank order is real information,
/// but the color itself is a flat fill per the app's card-stock system.
const podiumColors = [
  AppPalette.mutedGold,
  Color(0xFFB9AFA0), // warm silver-grey, kept in the parchment family
  Color(0xFF9C7A4E), // warm bronze-brown
];

const podiumShadowColors = [
  Color(0xFF9C7A33),
  Color(0xFF8A8070),
  Color(0xFF6B4F2E),
];

BoxDecoration podiumOrFlatDecoration({
  required int index,
  required ColorScheme colors,
  bool highlighted = false,
}) {
  if (index < podiumColors.length) {
    final tone = podiumColors[index];
    return BoxDecoration(
      color: Color.alphaBlend(tone.withValues(alpha: 0.22), AppPalette.cardStock),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tone.withValues(alpha: 0.6), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: AppPalette.shadowInk,
          blurRadius: 10,
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
  if (index >= podiumColors.length) return const SizedBox.shrink();
  return MedalIcon(size: size * 0.9, color: podiumColors[index]);
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
        final isPodium = index < podiumColors.length;

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
