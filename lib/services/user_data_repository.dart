import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/translation_record.dart';

/// Translation history and favorites, stored on the phone.
class UserDataRepository {
  UserDataRepository(this._db);

  static const historyLimit = 200;

  final Database _db;

  /// Bumped after every change so open screens can refresh.
  final changes = ValueNotifier<int>(0);

  static Future<UserDataRepository> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'user.db');
    final db = await openDatabase(dbPath, version: 1, onCreate: createSchema);
    return UserDataRepository(db);
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        target TEXT NOT NULL,
        source_text TEXT NOT NULL,
        result_text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        favorite INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute(
      'CREATE INDEX idx_records_lookup ON records (source, target, source_text)',
    );
  }

  /// Saves a translation to history. Translating the same text again moves
  /// the existing record to the top instead of adding a duplicate.
  Future<TranslationRecord> addToHistory(TranslationRecord record) async {
    final existing = await _db.query(
      'records',
      where: 'source = ? AND target = ? AND source_text = ?',
      whereArgs: [record.source.code, record.target.code, record.sourceText],
      limit: 1,
    );
    late final TranslationRecord saved;
    if (existing.isNotEmpty) {
      final old = TranslationRecord.fromRow(existing.first);
      saved = record.copyWith(id: old.id, favorite: old.favorite);
      await _db.update(
        'records',
        saved.toRow(),
        where: 'id = ?',
        whereArgs: [old.id],
      );
    } else {
      saved = record.copyWith(id: await _db.insert('records', record.toRow()));
    }
    await _trimHistory();
    changes.value++;
    return saved;
  }

  Future<List<TranslationRecord>> history() async {
    final rows = await _db.query(
      'records',
      orderBy: 'created_at DESC, id DESC',
      limit: historyLimit,
    );
    return rows.map(TranslationRecord.fromRow).toList();
  }

  Future<List<TranslationRecord>> favorites() async {
    final rows = await _db.query(
      'records',
      where: 'favorite = 1',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(TranslationRecord.fromRow).toList();
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await _db.update(
      'records',
      {'favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    changes.value++;
  }

  Future<void> delete(int id) async {
    await _db.delete('records', where: 'id = ?', whereArgs: [id]);
    changes.value++;
  }

  /// Clears history but keeps favorites.
  Future<void> clearHistory() async {
    await _db.delete('records', where: 'favorite = 0');
    changes.value++;
  }

  /// Drops the oldest non-favorite records beyond [historyLimit].
  Future<void> _trimHistory() => _db.rawDelete(
    '''
      DELETE FROM records WHERE favorite = 0 AND id NOT IN (
        SELECT id FROM records ORDER BY created_at DESC, id DESC LIMIT ?
      )''',
    [historyLimit],
  );

  Future<void> close() => _db.close();
}
