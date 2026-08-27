import 'package:flutter/material.dart';
import '../realtime/match_socket.dart';

class Leaderboard extends StatelessWidget {
  final List<FinalStanding> standings;
  final String? highlightName;

  const Leaderboard({Key? key, required this.standings, this.highlightName}) : super(key: key);

  static const _medalColors = [Colors.amber, Colors.grey, Colors.brown];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: standings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final standing = standings[index];
        final isMe = !standing.isBot && standing.name == highlightName;
        final medalColor = index < _medalColors.length ? _medalColors[index] : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? colors.primary.withValues(alpha: 0.10) : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe ? colors.primary.withValues(alpha: 0.4) : colors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: medalColor != null
                    ? Icon(Icons.emoji_events, color: medalColor, size: 22)
                    : Text(
                        '${standing.placement}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  standing.isBot ? 'Bot' : standing.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${standing.total} pts',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}
