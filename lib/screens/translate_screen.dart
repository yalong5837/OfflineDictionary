import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_language.dart';
import '../models/dictionary_entry.dart';
import '../models/translation_record.dart';
import '../services/app_services.dart';
import '../widgets/entry_tile.dart';
import '../widgets/language_picker.dart';
import '../widgets/model_download.dart';

/// Main screen: type text, get an offline translation plus dictionary entries.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _input = TextEditingController();

  /// Null means detect the input language automatically.
  AppLanguage? _source;
  AppLanguage _target = AppLanguage.en;

  AppLanguage? _detected;
  TranslationRecord? _record;
  List<DictionaryEntry> _entries = const [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    final services = AppServices.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final from =
          _source ?? await services.detector.detect(text) ?? AppLanguage.zh;
      var to = _target;
      if (from == to) {
        // Auto-detected the target language: translate the other way.
        to = from == AppLanguage.zh ? AppLanguage.en : AppLanguage.zh;
      }
      if (!mounted) return;
      final missing = await services.translation.missingModels(from, to);
      if (!mounted) return;
      if (!await ensureModels(context, services.translation, missing)) {
        setState(() => _busy = false);
        return;
      }
      final result = await services.translation.translate(text, from, to);
      final record = await services.userData.addToHistory(
        TranslationRecord(
          source: from,
          target: to,
          sourceText: text,
          resultText: result,
          createdAt: DateTime.now(),
        ),
      );
      final entries = _looksLikeWord(text)
          ? await services.dictionary.lookup(text, from, to)
          : const <DictionaryEntry>[];
      if (!mounted) return;
      setState(() {
        _detected = _source == null ? from : null;
        _record = record;
        _entries = entries;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '翻译失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _looksLikeWord(String text) => text.length <= 40 && !text.contains('\n');

  void _swap() {
    final from = _source ?? _detected;
    setState(() {
      _source = _target;
      _target = from ?? AppLanguage.zh;
      if (_record != null) {
        _input.text = _record!.resultText;
        _record = null;
        _entries = const [];
      }
      _detected = null;
    });
  }

  Future<void> _toggleFavorite() async {
    final record = _record;
    if (record?.id == null) return;
    final favorite = !record!.favorite;
    await AppServices.of(context).userData.setFavorite(record.id!, favorite);
    setState(() => _record = record.copyWith(favorite: favorite));
  }

  Future<void> _speak(String text, AppLanguage language) async {
    final ok = await AppServices.of(context).speech.speak(text, language);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('手机上没有${language.label}语音，可在系统设置中添加')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = _record;
    return Scaffold(
      appBar: AppBar(title: const Text('离线翻译')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: LanguagePicker(
                    value: _source,
                    allowAuto: true,
                    autoLabel: _detected == null
                        ? '自动检测'
                        : '自动（${_detected!.label}）',
                    onChanged: (v) => setState(() {
                      _source = v;
                      _detected = null;
                    }),
                  ),
                ),
              ),
              IconButton(
                tooltip: '交换语言',
                icon: const Icon(Icons.swap_horiz),
                onPressed: _swap,
              ),
              Expanded(
                child: Center(
                  child: LanguagePicker(
                    value: _target,
                    onChanged: (v) => setState(() => _target = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _input,
            minLines: 3,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '输入要翻译的文字',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _input.clear();
                  _record = null;
                  _entries = const [];
                  _error = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _translate,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.translate),
            label: const Text('翻译'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (record != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.source.label} → ${record.target.label}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      record.resultText,
                      style: theme.textTheme.titleLarge,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '朗读',
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () =>
                              _speak(record.resultText, record.target),
                        ),
                        IconButton(
                          tooltip: '复制',
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: record.resultText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制')),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: record.favorite ? '取消收藏' : '收藏',
                          icon: Icon(
                            record.favorite ? Icons.star : Icons.star_border,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('词典释义', style: theme.textTheme.titleSmall),
            for (final entry in _entries)
              EntryTile(
                entry: entry,
                onSpeak: () => _speak(entry.headword, entry.language),
              ),
          ],
        ],
      ),
    );
  }
}
