import 'package:audioplayers/audioplayers.dart';

/// Plays Seerah Maze's short sound effects. A feature-scoped singleton
/// (same shape as services/sound_service.dart's app-wide one, but never
/// imported from here — this feature stays standalone from the quiz
/// engine) — a dedicated [AudioPlayer] per effect so overlapping triggers
/// (e.g. a quick run of steps) replay without cutting each other off.
///
/// Every asset path below lives under assets/sounds/maze/, which ships
/// with no actual audio files yet; [enabled] gates playback and every
/// play call is wrapped in try/catch, so a missing or corrupt asset is
/// silently skipped rather than interrupting gameplay — per this
/// feature's "sound must fail silently if assets are missing" rule. Drop
/// real clips in at these exact paths whenever they're ready; nothing
/// else needs to change.
class MazeAudioService {
  MazeAudioService._() {
    // audioplayers logs every playback failure itself (via its internal
    // AudioLogger), independently of the try/catch in _play below — so
    // without this, the expected "no asset file yet" errors still spam
    // devtools/Sentry even though gameplay is unaffected.
    AudioLogger.logLevel = AudioLogLevel.none;
  }

  static final MazeAudioService instance = MazeAudioService._();

  bool enabled = true;

  final AudioPlayer _stepPlayer = AudioPlayer();
  final AudioPlayer _bumpPlayer = AudioPlayer();
  final AudioPlayer _starPlayer = AudioPlayer();
  final AudioPlayer _hintPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _buttonPlayer = AudioPlayer();

  Future<void> playStep() => _play(_stepPlayer, 'sounds/maze/step.mp3');
  Future<void> playBump() => _play(_bumpPlayer, 'sounds/maze/bump.mp3');
  Future<void> playStar() => _play(_starPlayer, 'sounds/maze/star.mp3');
  Future<void> playHint() => _play(_hintPlayer, 'sounds/maze/hint.mp3');
  Future<void> playWin() => _play(_winPlayer, 'sounds/maze/win.mp3');
  Future<void> playButtonTap() => _play(_buttonPlayer, 'sounds/maze/button_tap.mp3');

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (!enabled) return;
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // See the class doc comment — missing/corrupt assets are expected
      // right now and must stay silent, not break anything.
    }
  }

  void dispose() {
    for (final player in [
      _stepPlayer,
      _bumpPlayer,
      _starPlayer,
      _hintPlayer,
      _winPlayer,
      _buttonPlayer
    ]) {
      player.dispose();
    }
  }
}
