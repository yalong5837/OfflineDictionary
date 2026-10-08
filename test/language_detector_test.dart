import 'package:flutter_test/flutter_test.dart';
import 'package:offline_dictionary/models/app_language.dart';
import 'package:offline_dictionary/services/language_detector.dart';

void main() {
  final detector = LanguageDetector(
    identifyLatin: (text) async => text.contains('bonjour') ? 'fr' : 'en',
  );

  test('detects languages by script', () async {
    expect(await detector.detect('你好世界'), AppLanguage.zh);
    expect(await detector.detect('こんにちは'), AppLanguage.ja);
    expect(await detector.detect('日本語を勉強する'), AppLanguage.ja);
    expect(await detector.detect('안녕하세요'), AppLanguage.ko);
  });

  test('uses language ID for Latin text', () async {
    expect(await detector.detect('hello world'), AppLanguage.en);
    expect(await detector.detect('bonjour le monde'), AppLanguage.fr);
  });

  test('falls back to English when language ID fails', () async {
    final failing = LanguageDetector(identifyLatin: (_) => throw Exception());
    expect(await failing.detect('hello'), AppLanguage.en);
  });

  test('returns null without letters', () async {
    expect(await detector.detect('123 !?'), isNull);
  });
}
