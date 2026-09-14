import 'package:flutter_tts/flutter_tts.dart';

/// Speaks a word's Arabic script using the device's native text-to-speech
/// voice. This is deliberately device-TTS, not a curated pronunciation
/// recording — quality varies by device/platform and generic voices can
/// mispronounce proper nouns, but it's real audible Arabic with no bundled
/// voice-clip assets to source or license. Mirrors SoundService's
/// resilience pattern: any failure (no Arabic voice installed, TTS
/// unavailable on this platform, ...) is swallowed rather than surfaced,
/// since hearing the word is a bonus on top of already seeing it.
class ArabicTtsService {
  ArabicTtsService._();

  static final ArabicTtsService instance = ArabicTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.4); // slower than default — clearer for learners
      await _tts.setVolume(1.0);
    } catch (_) {
      // If configuration fails, speak() below will likely also fail and
      // swallow it the same way — nothing more to do here.
    }
  }

  Future<void> speak(String arabicScript) async {
    if (arabicScript.isEmpty) return;
    try {
      await _ensureConfigured();
      await _tts.stop();
      await _tts.speak(arabicScript);
    } catch (_) {
      // No Arabic voice on this device, TTS unsupported on this platform,
      // etc. — a silent no-op is the right fallback, not an error banner.
    }
  }

  void dispose() {
    _tts.stop();
  }
}
