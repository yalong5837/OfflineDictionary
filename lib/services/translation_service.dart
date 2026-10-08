import 'dart:async';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../models/app_language.dart';

/// On-device translation through Google ML Kit. Each language needs its model
/// (about 30 MB) downloaded once; after that translation works offline.
class TranslationService {
  final _models = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};

  Future<bool> isDownloaded(AppLanguage language) =>
      _models.isModelDownloaded(language.code);

  /// Languages whose model is missing for translating [from] into [to].
  Future<List<AppLanguage>> missingModels(
    AppLanguage from,
    AppLanguage to,
  ) async {
    final missing = <AppLanguage>[];
    for (final language in {from, to}) {
      if (!await isDownloaded(language)) missing.add(language);
    }
    return missing;
  }

  /// Downloads the model for [language]. Returns false if the download
  /// failed, and throws [TimeoutException] if it did not finish in [timeout].
  ///
  /// The download goes through a translator rather than the model manager:
  /// on iOS the model manager downloads in a background session, which can
  /// stall without ever reporting success or failure (notably in the
  /// simulator). A translator downloads its models in the foreground.
  Future<bool> download(
    AppLanguage language, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (await isDownloaded(language)) return true;
    // Every translation needs English, so pairing with it adds nothing extra.
    final partner = language == AppLanguage.en
        ? AppLanguage.zh
        : AppLanguage.en;
    try {
      await translate('ok', language, partner).timeout(timeout);
    } on TimeoutException {
      rethrow;
    } catch (_) {
      return false;
    }
    return isDownloaded(language);
  }

  Future<bool> delete(AppLanguage language) async {
    await _closeTranslatorsUsing(language);
    return _models.deleteModel(language.code);
  }

  Future<String> translate(
    String text,
    AppLanguage from,
    AppLanguage to,
  ) async {
    if (from == to) return text;
    final translator = _translators.putIfAbsent(
      '${from.code}>${to.code}',
      () => OnDeviceTranslator(
        sourceLanguage: from.mlKit,
        targetLanguage: to.mlKit,
      ),
    );
    return translator.translateText(text);
  }

  Future<void> _closeTranslatorsUsing(AppLanguage language) async {
    final keys = _translators.keys
        .where((k) => k.split('>').contains(language.code))
        .toList();
    for (final key in keys) {
      await _translators.remove(key)!.close();
    }
  }

  Future<void> dispose() async {
    for (final translator in _translators.values) {
      await translator.close();
    }
    _translators.clear();
  }
}
