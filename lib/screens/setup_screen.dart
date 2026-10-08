import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../services/app_services.dart';

/// Shown before the app on first launch: downloads the Chinese and English
/// language packs so the core translation direction works offline from then
/// on. ML Kit cannot ship models inside the app, so this needs network once.
class SetupGate extends StatefulWidget {
  const SetupGate({super.key, required this.child});

  /// Packs every install gets up front.
  static const defaultLanguages = [AppLanguage.zh, AppLanguage.en];

  final Widget child;

  @override
  State<SetupGate> createState() => _SetupGateState();
}

enum _Stage { checking, downloading, failed, ready }

class _SetupGateState extends State<SetupGate> {
  _Stage _stage = _Stage.checking;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final translation = AppServices.of(context).translation;
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    try {
      final missing = <AppLanguage>[];
      for (final language in SetupGate.defaultLanguages) {
        if (!await translation.isDownloaded(language)) missing.add(language);
      }
      if (missing.isNotEmpty) {
        if (!mounted) return;
        setState(() => _stage = _Stage.downloading);
        for (final language in missing) {
          if (!await translation.download(language)) {
            throw Exception('download failed');
          }
        }
      }
      if (mounted) setState(() => _stage = _Stage.ready);
    } on TimeoutException {
      _fail('下载超时');
    } catch (_) {
      _fail('下载失败');
    }
  }

  void _fail(String message) {
    // Already skipped: let the app carry on without interrupting.
    if (mounted && _stage != _Stage.ready) {
      setState(() {
        _stage = _Stage.failed;
        _error = message;
      });
    }
  }

  void _skip() => setState(() => _stage = _Stage.ready);

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.ready) return widget.child;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('准备离线翻译', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                switch (_stage) {
                  _Stage.checking => '正在检查语言包…',
                  _Stage.downloading =>
                    '第一次使用需要下载中文和英语语言包（约 60MB），'
                        '只需下载一次，之后不联网也能翻译。',
                  _ =>
                    '$_error，请检查网络后重试。\n'
                        '也可以先跳过，词典查词不需要语言包。',
                },
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (_stage == _Stage.failed) ...[
                FilledButton(onPressed: _prepare, child: const Text('重试')),
                const SizedBox(height: 8),
                TextButton(onPressed: _skip, child: const Text('先跳过')),
              ] else ...[
                const CircularProgressIndicator(),
                if (_stage == _Stage.downloading) ...[
                  const SizedBox(height: 24),
                  TextButton(onPressed: _skip, child: const Text('先跳过')),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
