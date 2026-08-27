import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.token});

  final String token;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ProfileApi _api = ProfileApi();
  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _api.fetchLeaderboard(widget.token);
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static const _medalColors = [Colors.amber, Colors.grey, Colors.brown];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Leaderboard'),
      body: _loading
          ? const LoadingView(message: 'Loading top players…', icon: Icons.leaderboard_rounded)
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? const Center(child: Text('No players yet — be the first!'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ListView.separated(
                              padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 24),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _LeaderboardTile(
                                entry: _entries[i],
                                medalColor: i < _medalColors.length ? _medalColors[i] : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry, required this.medalColor});

  final LeaderboardEntry entry;
  final Color? medalColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medalColor != null
                ? Icon(Icons.emoji_events, color: medalColor, size: 24)
                : Text(
                    '${entry.placement}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (entry.streakDays > 0) ...[
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
            const SizedBox(width: 2),
            Text('${entry.streakDays}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
          ],
          Text(
            '${entry.totalXp} XP',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
