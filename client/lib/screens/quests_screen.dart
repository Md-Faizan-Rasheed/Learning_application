import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/game_api.dart' show kApiBaseUrl, describeApiError;
import '../l10n/app_localizations.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';

class Quest {
  Quest({
    required this.key,
    required this.description,
    required this.target,
    required this.progress,
    required this.completed,
    required this.rewardXp,
  });
  final String key;
  final String description;
  final int target;
  final int progress;
  final bool completed;
  final int rewardXp;

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        key: j['quest_key'] as String,
        description: j['description'] as String,
        target: j['target'] as int,
        progress: j['progress'] as int,
        completed: j['completed'] as bool,
        rewardXp: j['reward_xp'] as int,
      );
}

class QuestsApi {
  QuestsApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Quest>> fetch(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/quests'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(
          describeApiError(res, 'Could not load quests (${res.statusCode}).'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['quests'] as List)
        .map((e) => Quest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key, required this.token});
  final String token;

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  final QuestsApi _api = QuestsApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<Quest> _quests = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      final q = await _api.fetch(widget.token);
      setState(() {
        _quests = q;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
          title: t.questsTitle,
          scrollController: (_loading || _error != null || _quests.isEmpty)
              ? null
              : _scrollController),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: _loading
                ? LoadingView(
                    message: t.questsLoading, icon: Icons.checklist_rounded)
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load, child: Text(t.retry)),
                          ],
                        ),
                      )
                    : _quests.isEmpty
                        ? Center(child: Text(t.questsEmpty))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final horizontalPadding =
                                  constraints.maxWidth >= 600 ? 32.0 : 16.0;
                              return Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 640),
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                        horizontalPadding,
                                        20,
                                        horizontalPadding,
                                        24),
                                    itemCount: _quests.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, i) =>
                                        _QuestCard(quest: _quests[i]),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final pct = quest.target == 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);
    final done = quest.completed;

    final onSurface = done ? Colors.white : null;
    final trackColor = done
        ? Colors.white.withValues(alpha: 0.3)
        : colors.outlineVariant.withValues(alpha: 0.4);
    final barColor = done ? Colors.white : colors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: done
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            )
          : BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? Colors.white : colors.outline,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quest.description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: done
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded,
                          size: 14,
                          color: done ? Colors.white : Colors.amber.shade800),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          t.questRewardXp(quest.rewardXp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: done ? Colors.white : Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done
                ? t.questCompletedBadge
                : t.questProgress(quest.progress, quest.target),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurface?.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}
