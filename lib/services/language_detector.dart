import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

import '../models/app_language.dart';

/// Picks the input language. Scripts settle Chinese, Japanese and Korean;
/// Latin text (English or French) goes to ML Kit's offline language ID.
class LanguageDetector {
  LanguageDetector({Future<String> Function(String text)? identifyLatin})
    : _identifyLatin = identifyLatin ?? _mlKitIdentify;

  final Future<String> Function(String text) _identifyLatin;

  static final _hangul = RegExp(r'[가-힯ᄀ-ᇿ㄰-㆏]');
  static final _kana = RegExp(r'[぀-ヿㇰ-ㇿ]');
  static final _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');
  static final _latin = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿŒœ]');

  static LanguageIdentifier? _identifier;

  static Future<String> _mlKitIdentify(String text) =>
      (_identifier ??= LanguageIdentifier(
        confidenceThreshold: 0.4,
      )).identifyLanguage(text);

  /// Returns null when the text has no letters at all.
  Future<AppLanguage?> detect(String text) async {
    if (_hangul.hasMatch(text)) return AppLanguage.ko;
    if (_kana.hasMatch(text)) return AppLanguage.ja;
    if (_han.hasMatch(text)) return AppLanguage.zh;
    if (!_latin.hasMatch(text)) return null;
    try {
      final code = await _identifyLatin(text);
      return code == 'fr' ? AppLanguage.fr : AppLanguage.en;
    } catch (_) {
      return AppLanguage.en;
    }
  }
}
