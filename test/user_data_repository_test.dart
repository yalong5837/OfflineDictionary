import 'package:flutter_test/flutter_test.dart';
import 'package:offline_dictionary/models/app_language.dart';
import 'package:offline_dictionary/models/translation_record.dart';
import 'package:offline_dictionary/services/user_data_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late UserDataRepository repo;

  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: UserDataRepository.createSchema,
      ),
    );
    repo = UserDataRepository(db);
  });

  tearDown(() => repo.close());

  TranslationRecord record(String text, {int minute = 0}) => TranslationRecord(
    source: AppLanguage.zh,
    target: AppLanguage.en,
    sourceText: text,
    resultText: 'result of $text',
    createdAt: DateTime(2026, 1, 1, 0, minute),
  );

  test('newest history first, no duplicates', () async {
    await repo.addToHistory(record('一', minute: 1));
    await repo.addToHistory(record('二', minute: 2));
    await repo.addToHistory(record('一', minute: 3));
    final history = await repo.history();
    expect(history.map((r) => r.sourceText), ['一', '二']);
  });

  test('favorites survive clearing history', () async {
    final saved = await repo.addToHistory(record('收藏'));
    await repo.addToHistory(record('普通'));
    await repo.setFavorite(saved.id!, true);
    await repo.clearHistory();
    expect((await repo.history()).map((r) => r.sourceText), ['收藏']);
    expect((await repo.favorites()).single.favorite, isTrue);
  });

  test('re-translating keeps the favorite flag', () async {
    final saved = await repo.addToHistory(record('词'));
    await repo.setFavorite(saved.id!, true);
    final again = await repo.addToHistory(record('词', minute: 5));
    expect(again.favorite, isTrue);
    expect(again.id, saved.id);
  });

  test('history is capped, favorites are kept', () async {
    final first = await repo.addToHistory(record('最早'));
    await repo.setFavorite(first.id!, true);
    for (var i = 0; i < UserDataRepository.historyLimit + 5; i++) {
      await repo.addToHistory(record('第$i', minute: i % 60 + 1));
    }
    expect((await repo.favorites()).single.sourceText, '最早');
    expect(await repo.history(), hasLength(UserDataRepository.historyLimit));
  });

  test('notifies listeners on change', () async {
    var notified = 0;
    repo.changes.addListener(() => notified++);
    final saved = await repo.addToHistory(record('变'));
    await repo.setFavorite(saved.id!, true);
    await repo.delete(saved.id!);
    expect(notified, 3);
  });
}
