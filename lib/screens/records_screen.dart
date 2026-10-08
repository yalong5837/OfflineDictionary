import 'package:flutter/material.dart';

import '../models/translation_record.dart';
import '../services/app_services.dart';

/// Translation history and favorites.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = AppServices.of(context).userData;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('记录'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '收藏'),
              Tab(text: '历史'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '清空历史',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: const Text('清空所有历史记录？收藏的内容会保留。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await userData.clearHistory();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _RecordList(load: userData.favorites, empty: '还没有收藏，翻译后点 ☆ 收藏'),
            _RecordList(load: userData.history, empty: '还没有翻译记录'),
          ],
        ),
      ),
    );
  }
}

class _RecordList extends StatefulWidget {
  const _RecordList({required this.load, required this.empty});

  final Future<List<TranslationRecord>> Function() load;
  final String empty;

  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  List<TranslationRecord>? _records;
  ValueNotifier<int>? _changes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = AppServices.of(context).userData.changes;
    if (_changes != changes) {
      _changes?.removeListener(_reload);
      _changes = changes..addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    _changes?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final records = await widget.load();
    if (mounted) setState(() => _records = records);
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    if (records == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (records.isEmpty) {
      return Center(child: Text(widget.empty));
    }
    final services = AppServices.of(context);
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final record = records[i];
        return Dismissible(
          key: ValueKey(record.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => services.userData.delete(record.id!),
          child: ListTile(
            title: Text(
              record.sourceText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${record.resultText}\n${record.source.label} → ${record.target.label}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: record.favorite ? '取消收藏' : '收藏',
              icon: Icon(record.favorite ? Icons.star : Icons.star_border),
              onPressed: () =>
                  services.userData.setFavorite(record.id!, !record.favorite),
            ),
            onLongPress: () =>
                services.speech.speak(record.resultText, record.target),
          ),
        );
      },
    );
  }
}
