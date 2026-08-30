import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/recorder/recorder_screen.dart';
import 'features/settings/settings_screen.dart';

class MikroApp extends ConsumerWidget {
  const MikroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obie wersje motywu budujemy zawsze — MaterialApp sam wybiera po themeMode, dzieki czemu
    // przelaczenie systemu na ciemny nie wymaga przebudowy drzewa providerow.
    final palette = ref.watch(themePaletteProvider);
    return MaterialApp(
      title: 'Mikro',
      theme: buildTheme(palette: palette, brightness: Brightness.light),
      darkTheme: buildTheme(palette: palette, brightness: Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      // Pierwsze uruchomienie idzie przez onboarding, kolejne prosto do powloki.
      home: const OnboardingGate(child: HomeShell()),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          const RecorderScreen(),
          const LibraryScreen(),
          const SettingsScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic), label: 'Nagrywaj'),
            NavigationDestination(icon: Icon(Icons.library_music), label: 'Biblioteka'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Ustawienia'),
          ],
        ),
      );
}
