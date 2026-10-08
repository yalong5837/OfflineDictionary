import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Languages the app translates between. Chinese is the home language.
enum AppLanguage {
  zh('中文', TranslateLanguage.chinese, 'zh-CN'),
  en('英语', TranslateLanguage.english, 'en-US'),
  ja('日语', TranslateLanguage.japanese, 'ja-JP'),
  ko('韩语', TranslateLanguage.korean, 'ko-KR'),
  fr('法语', TranslateLanguage.french, 'fr-FR');

  const AppLanguage(this.label, this.mlKit, this.ttsLocale);

  /// Name shown in the UI (in Chinese).
  final String label;
  final TranslateLanguage mlKit;
  final String ttsLocale;

  /// Code used by ML Kit's model manager and the dictionary database.
  String get code => mlKit.bcpCode;

  static AppLanguage fromCode(String code) =>
      values.firstWhere((l) => l.code == code || l.name == code);
}
