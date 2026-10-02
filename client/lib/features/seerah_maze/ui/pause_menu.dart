import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/maze_audio_service.dart';
import '../models/maze_progress.dart';
import 'responsive/maze_breakpoints.dart';

/// What the player chose from the pause menu.
enum MazePauseAction { resume, restart, levelSelect }

/// Shows the pause menu as a non-dismissible-by-accident dialog (back
/// button/scrim tap both resolve to "resume", matching "pausing is never
/// destructive"). Settings toggles edit a local copy of [progress] live
/// and the dialog always resolves with the latest copy alongside the
/// chosen action, so the caller can persist it and apply toggles like
/// `fogEnabled` immediately.
Future<(MazePauseAction, MazeProgress)> showMazePauseMenu(
  BuildContext context, {
  required MazeProgress progress,
}) async {
  final result = await showDialog<(MazePauseAction, MazeProgress)>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _PauseMenuContent(initialProgress: progress),
  );
  return result ?? (MazePauseAction.resume, progress);
}

class _PauseMenuContent extends StatefulWidget {
  const _PauseMenuContent({required this.initialProgress});

  final MazeProgress initialProgress;

  @override
  State<_PauseMenuContent> createState() => _PauseMenuContentState();
}

class _PauseMenuContentState extends State<_PauseMenuContent> {
  late MazeProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
  }

  void _resolve(MazePauseAction action) {
    MazeAudioService.instance.playButtonTap();
    Navigator.of(context).pop((action, _progress));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _resolve(MazePauseAction.resume);
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.mazePausedTitle),
        content: MazeClampedTextScale(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.mazeSoundToggle),
                value: _progress.soundEnabled,
                onChanged: (v) => setState(() => _progress = _progress.copyWith(soundEnabled: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.mazeHapticsToggle),
                value: _progress.hapticsEnabled,
                onChanged: (v) => setState(() => _progress = _progress.copyWith(hapticsEnabled: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.mazeJoystickToggle),
                value: _progress.joystickEnabled,
                onChanged: (v) =>
                    setState(() => _progress = _progress.copyWith(joystickEnabled: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.mazeFogToggle),
                value: _progress.fogEnabled,
                onChanged: (v) => setState(() => _progress = _progress.copyWith(fogEnabled: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.mazeReduceMotionToggle),
                value: _progress.reduceMotionEnabled,
                onChanged: (v) =>
                    setState(() => _progress = _progress.copyWith(reduceMotionEnabled: v)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => _resolve(MazePauseAction.resume),
                  child: Text(t.mazeResumeButton),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => _resolve(MazePauseAction.restart),
                  child: Text(t.mazeRestartButton),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: () => _resolve(MazePauseAction.levelSelect),
                  child: Text(t.mazeQuitButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
