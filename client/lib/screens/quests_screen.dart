import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/game_api.dart' show kApiBaseUrl;
import '../widgets/app_header.dart';

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
      throw Exception('Could not load quests (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
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
  bool _loading = true;
  String? _error;
  List<Quest> _quests = [];

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
    return Scaffold(
      appBar: const AppHeader(title: "Today's quests"),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _quests.map(_questCard).toList(),
                ),
    );
  }

  Widget _questCard(Quest q) {
    final pct = q.target == 0 ? 0.0 : (q.progress / q.target).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  q.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: q.completed ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(q.description,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('+${q.rewardXp} XP',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: q.completed ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 6),
            Text('${q.progress} / ${q.target}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
