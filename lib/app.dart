import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/recorder/recorder_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/home_tab.dart';

/// Destynacja powloki. Dolny pasek i rail rysuja te sama trojke, wiec stoi ona w jednym
/// miejscu — inaczej dolozenie zakladki wymagaloby pamietania o dwoch listach naraz.
@immutable
class _Destination {
  const _Destination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const _destinations = <_Destination>[
  _Destination(icon: Symbols.mic_rounded, label: 'Nagrywaj'),
  _Destination(icon: Symbols.library_music_rounded, label: 'Biblioteka'),
  _Destination(icon: Symbols.settings_rounded, label: 'Ustawienia'),
];

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

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    void select(int destination) =>
        ref.read(homeTabProvider.notifier).select(destination);

    // IndexedStack buduje wszystkie zakladki i trzyma ich stan, wiec przelaczenie nie gubi
    // ani pozycji listy, ani wpisanej frazy szukania.
    final body = IndexedStack(
      index: index,
      children: const [RecorderScreen(), LibraryScreen(), SettingsScreen()],
    );

    // Szerokosc bierzemy z MediaQuery, a nie z LayoutBuildera: rail i dolny pasek zajmuja
    // czesc okna, wiec mierzenie juz po ich odjeciu potrafiloby oscylowac wokol progu.
    if (MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint) {
      return Scaffold(
        body: Row(
          children: [
            _HomeRail(index: index, onSelected: select),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: _HomeNavigationBar(index: index, onSelected: select),
    );
  }
}

/// Dolny pasek z makiety telefonowej: wysokosc 80, tlo `surfaceContainer`, wskaznik 64x32
/// na `secondaryContainer`, etykieta wybranej destynacji pogrubiona do 700.
class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      // Makieta rysuje pasek plaski. Domyslna elewacja 3 dolozylaby przyciemnienie tinta,
      // przez ktore tlo przestaloby sie zgadzac z tokenem.
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 0.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon,
                fill: 1, size: 24, color: scheme.onSurfaceVariant),
            selectedIcon: Icon(destination.icon,
                fill: 1, size: 24, color: scheme.onSecondaryContainer),
            label: destination.label,
          ),
      ],
    );
  }
}

/// Rail z makiety tabletowej: szerokosc 96, tlo `surfaceContainer`, wskaznik 56x32.
///
/// Makieta stawia nad destynacjami kwadrat z mikrofonem, a pod nimi przycisk z paleta i nie
/// opisuje ich akcji. Ikona bez akcji jest gorsza niz jej brak, wiec obie prowadza tam, gdzie
/// nalezy dana sprawa: mikrofon na ekran Nagrywaj, paleta do Ustawien, gdzie stoi wybor
/// motywu. Decyzja odnotowana w raporcie.
class _HomeRail extends StatelessWidget {
  const _HomeRail({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      minWidth: 96,
      backgroundColor: scheme.surfaceContainer,
      labelType: NavigationRailLabelType.all,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      selectedIconTheme: IconThemeData(size: 24, color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(size: 24, color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: _RailButton(
          icon: Symbols.mic_rounded,
          iconSize: 28,
          background: scheme.primary,
          foreground: scheme.onPrimary,
          tooltip: 'Nagrywaj',
          onTap: () => onSelected(HomeTab.recorder),
        ),
      ),
      // `margin-top:auto` z makiety: przycisk siedzi przy dolnej krawedzi railu niezaleznie
      // od tego, ile miejsca zostalo nad nim.
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RailButton(
              icon: Symbols.palette_rounded,
              iconSize: 26,
              background: scheme.primaryContainer,
              foreground: scheme.onPrimaryContainer,
              tooltip: 'Wyglad',
              onTap: () => onSelected(HomeTab.settings),
            ),
          ),
        ),
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon, fill: 1),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// Kwadratowy przycisk railu: 56x56, promien 16, ikona wysrodkowana.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.iconSize,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const shape = BorderRadius.all(Radius.circular(16));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, fill: 1, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}
