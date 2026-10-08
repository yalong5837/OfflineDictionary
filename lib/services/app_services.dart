import 'package:flutter/widgets.dart';

import 'dictionary_repository.dart';
import 'language_detector.dart';
import 'speech_service.dart';
import 'translation_service.dart';
import 'user_data_repository.dart';

/// Makes the app's services available to every screen.
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.dictionary,
    required this.translation,
    required this.userData,
    required this.speech,
    required this.detector,
    required super.child,
  });

  final DictionaryRepository dictionary;
  final TranslationService translation;
  final UserDataRepository userData;
  final SpeechService speech;
  final LanguageDetector detector;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices oldWidget) => false;
}
