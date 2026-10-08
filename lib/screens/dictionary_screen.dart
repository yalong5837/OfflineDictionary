import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../models/dictionary_entry.dart';
import '../services/app_services.dart';
import '../widgets/entry_tile.dart';

/// Word lookup in the bundled dictionaries. Type Chinese to look up a
/// Chinese word, or a foreign word to see its Chinese meaning.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static final _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');
  static const _foreign = [
    AppLanguage.en,
    AppLanguage.ja,
    AppLanguage.ko,
    AppLanguage.fr,
  ];

  final _input = TextEditingController();
  AppLanguage _language = AppLanguage.en;
  bool _loading = false;

  /// Languages with a dictionary; null until loaded.
  Set<AppLanguage>? _available;
  List<DictionaryEntry> _results = const [];
  Timer? _debounce;
  int _searchId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    AppServices.of(context).dictionary.availableLanguages().then((langs) {
      if (mounted) setState(() => _available = langs);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _search);
  }

  Future<void> _search() async {
    final query = _input.text.trim();
    final id = ++_searchId;
    final dictionary = AppServices.of(context).dictionary;
    var results = <DictionaryEntry>[];
    if (query.isNotEmpty) {
      if (_han.hasMatch(query)) {
        results = await dictionary.suggest(query, AppLanguage.zh, _language);
        // Japanese words are often written in kanji only.
        if (_language == AppLanguage.ja) {
          results += await dictionary.suggest(
            query,
            AppLanguage.ja,
            AppLanguage.zh,
          );
        }
      } else {
        results = await dictionary.suggest(query, _language, AppLanguage.zh);
      }
    }
    if (mounted && id == _searchId) setState(() => _results = results);
  }

  void _showEntry(DictionaryEntry entry) {
    final speech = AppServices.of(context).speech;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: EntryTile(
            entry: entry,
            onSpeak: () => speech.speak(entry.headword, entry.language),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _available?.contains(_language) ?? true;
    final query = _input.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('词典')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<AppLanguage>(
              segments: [
                for (final language in _foreign)
                  ButtonSegment(
                    value: language,
                    label: Text('中${language.label.substring(0, 1)}'),
                  ),
              ],
              selected: {_language},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() => _language = s.first);
                _search();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _input,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '输入中文或${_language.label}单词',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: !available
                ? _Message('${_language.label}词典还没有收录，可以先用“翻译”页查询')
                : query.isEmpty
                ? const _Message('词典已内置在手机里，不联网也能查')
                : _results.isEmpty
                ? const _Message('没有找到这个词，可以去“翻译”页翻译')
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) => InkWell(
                      onTap: () => _showEntry(_results[i]),
                      child: EntryTile(entry: _results[i], dense: true),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
