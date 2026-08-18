import 'dart:async';

import 'package:flutter/material.dart';

import '../realtime/match_socket.dart';

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key, required this.lang, required this.name});

  final String lang;
  final String name;

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

enum _Phase { connecting, waiting, question, results, finished }

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final MatchSocket _socket = MatchSocket();
  final List<StreamSubscription> _subs = [];

  _Phase _phase = _Phase.connecting;
  List<MatchPlayer> _players = [];
  MatchQuestion? _question;
  RoundResult? _result;
  List<FinalStanding>? _finalStandings;
  int? _selected;
  bool _answered = false;

  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _subs.add(_socket.connected.listen((ok) {
      if (ok && _phase == _Phase.connecting) {
        _socket.findMatch(name: widget.name);
        setState(() => _phase = _Phase.waiting);
      }
    }));
    _subs.add(_socket.roster.listen((players) {
      setState(() => _players = players);
    }));
    _subs.add(_socket.question.listen((q) {
      setState(() {
        _question = q;
        _result = null;
        _selected = null;
        _answered = false;
        _phase = _Phase.question;
      });
      _startCountdown(q.deadlineMs);
    }));
    _subs.add(_socket.result.listen((r) {
      _ticker?.cancel();
      setState(() {
        _result = r;
        _phase = _Phase.results;
      });
    }));
    _subs.add(_socket.matchOver.listen((standings) {
      _ticker?.cancel();
      setState(() {
        _finalStandings = standings;
        _phase = _Phase.finished;
      });
    }));
    _socket.connect();
  }

  void _startCountdown(int deadlineMs) {
    _ticker?.cancel();
    void tick() {
      final left =
          ((deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      setState(() => _secondsLeft = left < 0 ? 0 : left);
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _submit() {
    if (_answered || _selected == null) return;
    _socket.submitAnswer(_selected);
    setState(() => _answered = true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multiplayer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_phase) {
          _Phase.connecting => const _Centered('Connecting…'),
          _Phase.waiting => _buildWaiting(),
          _Phase.question => _buildQuestion(),
          _Phase.results => _buildResults(),
          _Phase.finished => _buildFinished(),
        },
      ),
    );
  }

  Widget _buildWaiting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Match forming…', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        ..._players.map((p) => _seatTile(p)),
      ],
    );
  }

  Widget _seatTile(MatchPlayer p) {
    return ListTile(
      leading: CircleAvatar(child: Text('${p.seat + 1}')),
      title: Text(p.isBot ? 'Bot' : p.name),
      trailing: p.isBot
          ? const Icon(Icons.smart_toy, size: 18)
          : Icon(Icons.person,
              size: 18,
              color: p.connected ? Colors.green : Colors.grey),
    );
  }

  Widget _buildQuestion() {
    final q = _question!;
    final options = q.optionsFor(widget.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _result != null && _result!.totalRounds > 0
                  ? 'Q${q.index + 1} / ${_result!.totalRounds}'
                  : 'Q${q.index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _timerChip(),
          ],
        ),
        const SizedBox(height: 16),
        Text(q.promptFor(widget.lang),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        ...List.generate(options.length, (i) {
          final selected = _selected == i;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              onTap: _answered ? null : () => setState(() => _selected = i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12)
                      : null,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(options[i],
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        if (_answered)
          const Center(child: Text('Answer locked in — waiting for others…'))
        else
          FilledButton(
            onPressed: _selected == null ? null : _submit,
            child: const Text('Submit'),
          ),
      ],
    );
  }

  Widget _timerChip() {
    final urgent = _secondsLeft <= 5;
    return Chip(
      backgroundColor: urgent ? Colors.red.withValues(alpha: 0.15) : null,
      label: Text('$_secondsLeft s',
          style: TextStyle(
              color: urgent ? Colors.red : null,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildResults() {
    final r = _result!;
    final q = _question!;
    final options = q.optionsFor(widget.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Correct answer: ${options[r.correctIndex]}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 16),
        const Text('Leaderboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...r.rows.asMap().entries.map((e) {
          final rank = e.key + 1;
          final row = e.value;
          final isMe = !row.isBot && row.name == widget.name;
          return Card(
            color: isMe
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : null,
            child: ListTile(
              leading: Text('#$rank',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(row.isBot ? 'Bot' : row.name),
              subtitle: Text(row.isCorrect
                  ? '+${row.points} this round'
                  : 'no points'),
              trailing: Text('${row.total}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const SizedBox(height: 16),
        Center(
          child: Text(
            r.isFinal ? 'Final round complete…' : 'Next question coming up…',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final standings = _finalStandings!;
    final me = standings.firstWhere(
      (s) => !s.isBot && s.name == widget.name,
      orElse: () => standings.first,
    );
    final won = me.placement == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Icon(won ? Icons.emoji_events : Icons.flag,
                  size: 56, color: won ? Colors.amber : Colors.grey),
              const SizedBox(height: 8),
              Text(
                won ? 'You won!' : 'You placed #${me.placement}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Final standings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...standings.map((s) {
          final isMe = !s.isBot && s.name == widget.name;
          return Card(
            color: isMe
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : null,
            child: ListTile(
              leading: Text('#${s.placement}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(s.isBot ? 'Bot' : s.name),
              trailing: Text('${s.total}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home),
          label: const Text('Back to home'),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text),
        ],
      ),
    );
  }
}