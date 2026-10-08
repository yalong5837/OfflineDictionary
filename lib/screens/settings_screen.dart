import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../services/app_services.dart';

/// Offline language packs and data sources.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _downloaded = <AppLanguage, bool>{};
  final _working = <AppLanguage>{};
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) {
      _loading = true;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final translation = AppServices.of(context).translation;
    for (final language in AppLanguage.values) {
      try {
        final downloaded = await translation.isDownloaded(language);
        if (mounted) setState(() => _downloaded[language] = downloaded);
      } catch (_) {
        // Model status is unavailable (e.g. no Play services); leave unknown.
      }
    }
  }

  Future<void> _toggle(AppLanguage language) async {
    final translation = AppServices.of(context).translation;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working.add(language));
    try {
      final ok = _downloaded[language] == true
          ? await translation.delete(language)
          : await translation.download(language);
      if (!ok) {
        messenger.showSnackBar(const SnackBar(content: Text('操作失败，请检查网络后重试')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('操作失败，请检查网络后重试')));
    }
    if (!mounted) return;
    setState(() => _working.remove(language));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            title: Text('离线语言包', style: theme.textTheme.titleSmall),
            subtitle: const Text('整句翻译时，原文和译文的语言包都要先下载。每个约 30MB，下载后不联网也能翻译。'),
          ),
          for (final language in AppLanguage.values)
            ListTile(
              leading: Icon(
                _downloaded[language] == true
                    ? Icons.offline_pin
                    : Icons.cloud_download_outlined,
                color: _downloaded[language] == true
                    ? theme.colorScheme.primary
                    : null,
              ),
              title: Text(language.label),
              subtitle: Text(switch (_downloaded[language]) {
                true => '已下载，可离线使用',
                false => '未下载',
                null => '正在检查…',
              }),
              trailing: _working.contains(language)
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _downloaded[language] == null
                  ? null
                  : TextButton(
                      onPressed: () => _toggle(language),
                      child: Text(_downloaded[language] == true ? '删除' : '下载'),
                    ),
            ),
          const Divider(),
          ListTile(title: Text('关于', style: theme.textTheme.titleSmall)),
          ListTile(
            title: const Text('数据来源与许可'),
            subtitle: const Text('CC-CEDICT、ECDICT、维基词典、Google ML Kit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                showLicensePage(context: context, applicationName: '离线翻译'),
          ),
        ],
      ),
    );
  }
}
