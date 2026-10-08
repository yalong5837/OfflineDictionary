import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_language.dart';
import '../models/dictionary_entry.dart';

/// Read-only access to the bundled dictionary (see tools/build_dictionary.py).
class DictionaryRepository {
  DictionaryRepository(this._db);

  static const _asset = 'assets/dict/dictionary.db.gz';

  final Database _db;

  /// Unpacks the bundled dictionary on first launch (or after an app update
  /// ships a new one) and opens it.
  static Future<DictionaryRepository> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'dictionary.db');
    final stampFile = File(p.join(dir.path, 'dictionary.version'));

    final packed = await rootBundle.load(_asset);
    final stamp = '${packed.lengthInBytes}';
    final upToDate =
        File(dbPath).existsSync() &&
        stampFile.existsSync() &&
        stampFile.readAsStringSync() == stamp;
    if (!upToDate) {
      final bytes = await compute(_unpack, packed.buffer.asUint8List());
      await File(dbPath).writeAsBytes(bytes, flush: true);
      await stampFile.writeAsString(stamp);
    }
    return DictionaryRepository(await openDatabase(dbPath, readOnly: true));
  }

  static List<int> _unpack(Uint8List packed) => gzip.decode(packed);

  /// Languages that have a dictionary paired with Chinese.
  Future<Set<AppLanguage>> availableLanguages() async {
    final rows = await _db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['languages'],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    return (rows.first['value'] as String)
        .split(',')
        .where((c) => c.isNotEmpty)
        .map(AppLanguage.fromCode)
        .toSet();
  }

  /// Exact matches for [word] in [from], with definitions in [to].
  /// Every dictionary pairs with Chinese, so one side must be Chinese.
  Future<List<DictionaryEntry>> lookup(
    String word,
    AppLanguage from,
    AppLanguage to,
  ) async {
    final query = word.trim();
    if (query.isEmpty || !_pairedWithChinese(from, to)) return const [];
    final rows = await _db.query(
      'entries',
      where: from == AppLanguage.zh
          ? 'lang = ? AND target = ? AND (headword = ? OR alt = ?)'
          : 'lang = ? AND target = ? AND headword = ? COLLATE NOCASE',
      whereArgs: from == AppLanguage.zh
          ? [from.code, to.code, query, query]
          : [from.code, to.code, query],
      orderBy: 'rank, id',
      limit: 20,
    );
    return rows.map(DictionaryEntry.fromRow).toList();
  }

  /// Words in [from] starting with [prefix], shortest first.
  Future<List<DictionaryEntry>> suggest(
    String prefix,
    AppLanguage from,
    AppLanguage to, {
    int limit = 30,
  }) async {
    final query = prefix.trim();
    if (query.isEmpty || !_pairedWithChinese(from, to)) return const [];
    final rows = await _db.query(
      'entries',
      where:
          'lang = ? AND target = ? '
          'AND headword COLLATE NOCASE >= ? AND headword COLLATE NOCASE < ?',
      whereArgs: [from.code, to.code, query, '$query￿'],
      orderBy: 'length(headword), rank, id',
      limit: limit,
    );
    return rows.map(DictionaryEntry.fromRow).toList();
  }

  bool _pairedWithChinese(AppLanguage from, AppLanguage to) =>
      from != to && (from == AppLanguage.zh || to == AppLanguage.zh);

  Future<void> close() => _db.close();
}
