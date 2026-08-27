import 'package:audioplayers/audioplayers.dart';

/// Plays short sound effects bundled under assets/sounds/.
///
/// A dedicated [AudioPlayer] per effect lets overlapping triggers
/// (e.g. rapid-fire correct answers) replay without cutting each other off.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final AudioPlayer _correctPlayer = AudioPlayer();
  final AudioPlayer _incorrectPlayer = AudioPlayer();
  final AudioPlayer _countdownPlayer = AudioPlayer();

  bool enabled = true;

  Future<void> playCorrect() => _play(_correctPlayer, 'sounds/correct.mp3');

  Future<void> playIncorrect() => _play(_incorrectPlayer, 'sounds/incorrect.mp3');

  Future<void> playCountdown() => _play(_countdownPlayer, 'sounds/countdown.mp3');

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (!enabled) return;
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Sound is a nice-to-have; never let a playback failure break gameplay.
    }
  }

  void dispose() {
    _correctPlayer.dispose();
    _incorrectPlayer.dispose();
    _countdownPlayer.dispose();
  }
}
