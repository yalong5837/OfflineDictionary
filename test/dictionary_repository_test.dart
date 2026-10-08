import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_dictionary/models/app_language.dart';
import 'package:offline_dictionary/services/dictionary_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs against the real bundled dictionary.
void main() {
  late DictionaryRepository dictionary;
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    tmp = Directory.systemTemp.createTempSync('dict_test');
    final dbFile = File('${tmp.path}/dictionary.db')
      ..writeAsBytesSync(
        gzip.decode(File('assets/dict/dictionary.db.gz').readAsBytesSync()),
      );
    dictionary = DictionaryRepository(
      await databaseFactoryFfi.openDatabase(
        dbFile.path,
        options: OpenDatabaseOptions(readOnly: true),
      ),
    );
  });

  tearDownAll(() async {
    await dictionary.close();
    tmp.deleteSync(recursive: true);
  });

  test('looks up Chinese words with pinyin', () async {
    final entries = await dictionary.lookup(
      '你好',
      AppLanguage.zh,
      AppLanguage.en,
    );
    expect(entries, isNotEmpty);
    expect(entries.first.reading, 'nǐ hǎo');
    expect(entries.first.definition, contains('hello'));
  });

  test('finds traditional spellings', () async {
    final entries = await dictionary.lookup(
      '學習',
      AppLanguage.zh,
      AppLanguage.en,
    );
    expect(entries.map((e) => e.headword), contains('学习'));
  });

  test('looks up English words case-insensitively', () async {
    final entries = await dictionary.lookup(
      'Hello',
      AppLanguage.en,
      AppLanguage.zh,
    );
    expect(entries, isNotEmpty);
    expect(entries.first.definition, contains('喂'));
  });

  test('suggests words by prefix, shortest first', () async {
    final entries = await dictionary.suggest(
      'trans',
      AppLanguage.en,
      AppLanguage.zh,
    );
    expect(entries, isNotEmpty);
    expect(
      entries.every((e) => e.headword.toLowerCase().startsWith('trans')),
      isTrue,
    );
    expect(
      entries.first.headword.length,
      lessThanOrEqualTo(entries.last.headword.length),
    );
  });

  test('only pairs with Chinese', () async {
    expect(
      await dictionary.lookup('hello', AppLanguage.en, AppLanguage.fr),
      isEmpty,
    );
  });

  test('reports which languages have a dictionary', () async {
    expect(await dictionary.availableLanguages(), contains(AppLanguage.en));
  });
}
