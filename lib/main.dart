import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/app_services.dart';
import 'services/dictionary_repository.dart';
import 'services/language_detector.dart';
import 'services/speech_service.dart';
import 'services/translation_service.dart';
import 'services/user_data_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDataLicenses();
  runApp(const OfflineDictionaryApp());
}

class OfflineDictionaryApp extends StatelessWidget {
  const OfflineDictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '离线翻译',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _Bootstrap(),
    );
  }
}

/// Opens the dictionary and user data, then shows the app.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<(DictionaryRepository, UserDataRepository)> _ready = (
    DictionaryRepository.open(),
    UserDataRepository.open(),
  ).wait;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('启动失败：${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在准备离线词典…'),
                ],
              ),
            ),
          );
        }
        final (dictionary, userData) = snapshot.data!;
        return AppServices(
          dictionary: dictionary,
          userData: userData,
          translation: TranslationService(),
          speech: SpeechService(),
          detector: LanguageDetector(),
          child: const HomeScreen(),
        );
      },
    );
  }
}

void _registerDataLicenses() {
  LicenseRegistry.addLicense(
    () => Stream.fromIterable(const [
      LicenseEntryWithLineBreaks(
        ['CC-CEDICT'],
        'CC-CEDICT 中英词典，© MDBG，采用 Creative Commons Attribution-ShareAlike 4.0 许可。\nhttps://www.mdbg.net/chinese/dictionary?page=cc-cedict',
      ),
      LicenseEntryWithLineBreaks(
        ['ECDICT'],
        'ECDICT 英汉词典，© skywind3000，采用 MIT 许可。\nhttps://github.com/skywind3000/ECDICT',
      ),
      LicenseEntryWithLineBreaks(
        ['Wiktionary'],
        '中文与法语、日语、韩语词条整理自维基词典（Wiktionary）的翻译表，采用 Creative Commons Attribution-ShareAlike 4.0 许可。\nhttps://www.wiktionary.org',
      ),
    ]),
  );
}
