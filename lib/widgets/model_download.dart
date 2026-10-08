import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../services/translation_service.dart';

/// Asks to download the missing language packs, then downloads them while
/// showing progress. Returns true when every pack is ready.
Future<bool> ensureModels(
  BuildContext context,
  TranslationService translation,
  List<AppLanguage> missing,
) async {
  if (missing.isEmpty) return true;
  final names = missing.map((l) => l.label).join('、');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('需要下载语言包'),
      content: Text(
        '翻译需要先下载$names语言包（每个约 30MB）。'
        '下载一次后即可离线使用，建议连接 Wi-Fi。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('下载'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('正在下载语言包…')),
          ],
        ),
      ),
    ),
  );
  var ok = true;
  try {
    for (final language in missing) {
      ok = ok && await translation.download(language);
    }
  } catch (_) {
    ok = false;
  }
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('下载失败，请检查网络后重试')));
    }
  }
  return ok;
}
