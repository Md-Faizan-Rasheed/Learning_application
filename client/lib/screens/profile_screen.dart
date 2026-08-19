import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/game_api.dart' show kApiBaseUrl;

class MatchHistoryItem {
  MatchHistoryItem({
    required this.difficulty,
    required this.placement,
    required this.finalScore,
  });
  final String difficulty;
  final int? placement;
  final int? finalScore;

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) => MatchHistoryItem(
        difficulty: j['difficulty'] as String,
        placement: j['placement'] as int?,
        finalScore: j['final_score'] as int?,
      );
}

class Profile {
  Profile({
    required this.displayName,
    required this.totalXp,
    required this.streakDays,
    required this.streakFreezes,
    required this.recentMatches,
  });
  final String displayName;
  final int totalXp;
  final int streakDays;
  final int streakFreezes;
  final List<MatchHistoryItem> recentMatches;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        displayName: j['display_name'] as String,
        totalXp: j['total_xp'] as int,
        streakDays: j['streak_days'] as int,
        streakFreezes: (j['streak_freezes'] ?? 0) as int,
        recentMatches: (j['recent_matches'] as List)
            .map((e) => MatchHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Profile> fetch(String token) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/me/profile'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Could not load profile (${res.statusCode}).');
    }
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.token});
  final String token;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileApi _api = ProfileApi();
  bool _loading = true;
  String? _error;
  Profile? _profile;

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
      final p = await _api.fetch(widget.token);
      setState(() {
        _profile = p;
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
      appBar: AppBar(title: const Text('Profile')),
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
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final p = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                  value: '${p.streakDays}',
                  label: p.streakDays == 1 ? 'day streak' : 'day streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.star,
                  color: Colors.amber,
                  value: '${p.totalXp}',
                  label: 'total XP',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent matches',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (p.recentMatches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No matches yet — play one!')),
            )
          else
            ...p.recentMatches.map((m) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(m.placement != null ? '#${m.placement}' : '—'),
                    ),
                    title: Text('${m.difficulty[0].toUpperCase()}${m.difficulty.substring(1)} match'),
                    trailing: Text('${m.finalScore ?? 0} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}