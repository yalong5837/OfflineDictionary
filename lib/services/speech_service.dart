import 'package:flutter_tts/flutter_tts.dart';

import '../models/app_language.dart';

/// Reads text aloud with the phone's built-in (offline) speech engine.
class SpeechService {
  final _tts = FlutterTts();

  /// Returns false when the phone has no voice for [language].
  Future<bool> speak(String text, AppLanguage language) async {
    await _tts.stop();
    final available = await _tts.isLanguageAvailable(language.ttsLocale);
    if (available == false) return false;
    await _tts.setLanguage(language.ttsLocale);
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() => _tts.stop();
}
