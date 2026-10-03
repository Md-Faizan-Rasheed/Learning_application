import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../data/endless_run_repository.dart';
import '../data/maze_audio_service.dart';
import '../models/endless_best_run.dart';
import 'endless_play_screen.dart';
import 'responsive/maze_breakpoints.dart';

/// C3 — Endless mode's home: best run so far and a Start button. Mirrors
/// DailyMazeScreen's own "stats + one button" shape, injectable
/// [repository] for the same testability reason.
class EndlessHomeScreen extends StatefulWidget {
  const EndlessHomeScreen({super.key, this.repository = const EndlessRunRepository()});

  final EndlessRunRepository repository;

  @override
  State<EndlessHomeScreen> createState() => _EndlessHomeScreenState();
}

class _EndlessHomeScreenState extends State<EndlessHomeScreen> {
  EndlessBestRun _best = const EndlessBestRun();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final best = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _best = best;
      _loaded = true;
    });
  }

  Future<void> _start() async {
    MazeAudioService.instance.playButtonTap();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EndlessPlayScreen(repository: widget.repository)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: MazeColors.background,
          ),
        ),
        child: SafeArea(
          child: MazeClampedTextScale(
            child: MazeResponsiveBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Transform.flip(
                            flipX: Directionality.of(context) == TextDirection.rtl,
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            t.mazeEndlessTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.all_inclusive_rounded,
                      size: 72, color: MazeColors.destinationIcon.withValues(alpha: 0.9)),
                  const SizedBox(height: 16),
                  if (_loaded)
                    Text(
                      t.mazeEndlessHomeBestLabel(_best.bestRoundsCleared),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(t.mazeEndlessStartButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
