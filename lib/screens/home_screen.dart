import 'package:flutter/material.dart';

import 'dictionary_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'translate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          TranslateScreen(),
          DictionaryScreen(),
          RecordsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.translate), label: '翻译'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '词典',
          ),
          NavigationDestination(icon: Icon(Icons.star_border), label: '记录'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
