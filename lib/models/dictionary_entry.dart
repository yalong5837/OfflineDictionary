import 'app_language.dart';

/// One row of the bundled dictionary.
class DictionaryEntry {
  const DictionaryEntry({
    required this.language,
    required this.headword,
    required this.target,
    required this.definition,
    this.alt,
    this.reading,
  });

  /// Language of [headword].
  final AppLanguage language;
  final String headword;

  /// Alternative spelling, e.g. the traditional form of a Chinese word.
  final String? alt;

  /// Pinyin, phonetic transcription or romanization.
  final String? reading;

  /// Language [definition] is written in.
  final AppLanguage target;
  final String definition;

  factory DictionaryEntry.fromRow(Map<String, Object?> row) => DictionaryEntry(
    language: AppLanguage.fromCode(row['lang'] as String),
    headword: row['headword'] as String,
    alt: row['alt'] as String?,
    reading: row['reading'] as String?,
    target: AppLanguage.fromCode(row['target'] as String),
    definition: row['definition'] as String,
  );
}
