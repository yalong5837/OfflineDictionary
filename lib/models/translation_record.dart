import 'app_language.dart';

/// A translation kept in history or favorites.
class TranslationRecord {
  const TranslationRecord({
    this.id,
    required this.source,
    required this.target,
    required this.sourceText,
    required this.resultText,
    required this.createdAt,
    this.favorite = false,
  });

  final int? id;
  final AppLanguage source;
  final AppLanguage target;
  final String sourceText;
  final String resultText;
  final DateTime createdAt;
  final bool favorite;

  TranslationRecord copyWith({int? id, bool? favorite}) => TranslationRecord(
    id: id ?? this.id,
    source: source,
    target: target,
    sourceText: sourceText,
    resultText: resultText,
    createdAt: createdAt,
    favorite: favorite ?? this.favorite,
  );

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'source': source.code,
    'target': target.code,
    'source_text': sourceText,
    'result_text': resultText,
    'created_at': createdAt.millisecondsSinceEpoch,
    'favorite': favorite ? 1 : 0,
  };

  factory TranslationRecord.fromRow(Map<String, Object?> row) =>
      TranslationRecord(
        id: row['id'] as int,
        source: AppLanguage.fromCode(row['source'] as String),
        target: AppLanguage.fromCode(row['target'] as String),
        sourceText: row['source_text'] as String,
        resultText: row['result_text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
        ),
        favorite: (row['favorite'] as int) == 1,
      );
}
