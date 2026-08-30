import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/recorder/recorder_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/home_tab.dart';
import 'l10n/app_localizations.dart';

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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale?.languageCode == 'pl') return const Locale('pl');
        return const Locale('en');
      },
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
    final l10n = AppLocalizations.of(context);

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
            _HomeRail(index: index, onSelected: select, l10n: l10n),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: _HomeNavigationBar(index: index, onSelected: select, l10n: l10n),
    );
  }
}

/// Dolny pasek z makiety telefonowej: wysokosc 80, tlo `surfaceContainer`, wskaznik 64x32
/// na `secondaryContainer`, etykieta wybranej destynacji pogrubiona do 700.
class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.index, required this.onSelected, required this.l10n});

  final int index;
  final ValueChanged<int> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [l10n.navRecord, l10n.navLibrary, l10n.navSettings];
    final icons = [Symbols.mic_rounded, Symbols.library_music_rounded, Symbols.settings_rounded];
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
        for (var i = 0; i < labels.length; i++)
          NavigationDestination(
            icon: Icon(icons[i],
                fill: 1, size: 24, color: scheme.onSurfaceVariant),
            selectedIcon: Icon(icons[i],
                fill: 1, size: 24, color: scheme.onSecondaryContainer),
            label: labels[i],
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
  const _HomeRail({required this.index, required this.onSelected, required this.l10n});

  final int index;
  final ValueChanged<int> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [l10n.navRecord, l10n.navLibrary, l10n.navSettings];
    final icons = [Symbols.mic_rounded, Symbols.library_music_rounded, Symbols.settings_rounded];
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
          tooltip: l10n.navRecord,
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
              tooltip: l10n.navAppearance,
              onTap: () => onSelected(HomeTab.settings),
            ),
          ),
        ),
      ),
      destinations: [
        for (var i = 0; i < labels.length; i++)
          NavigationRailDestination(
            icon: Icon(icons[i], fill: 1),
            label: Text(labels[i]),
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
