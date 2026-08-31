import 'package:flutter/gestures.dart';
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

/// Enables drag scrolling for all input devices (including mouse and trackpad on desktop).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

class MikroApp extends ConsumerWidget {
  const MikroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both theme versions are always built — MaterialApp selects based on themeMode,
    // so switching system theme to dark does not require rebuilding the provider tree.
    final palette = ref.watch(themePaletteProvider);
    return MaterialApp(
      title: 'Mikro',
      scrollBehavior: const AppScrollBehavior(),
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
      // First launch goes through onboarding, subsequent launches go straight to the shell.
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

    // IndexedStack builds all tabs and retains their state, so switching tabs does not
    // lose the list scroll position or the entered search query.
    final body = IndexedStack(
      index: index,
      children: const [RecorderScreen(), LibraryScreen(), SettingsScreen()],
    );

    // Width is obtained from MediaQuery rather than LayoutBuilder: rail and bottom bar
    // take part of the window, so measuring after subtracting them could oscillate around the breakpoint.
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

/// Phone layout bottom navigation bar: height 80, background `surfaceContainer`, indicator 64x32
/// on `secondaryContainer`, selected destination label bolded to 700.
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
      // The design mockup renders a flat bar. The default elevation of 3 would add tint darkening,
      // which would cause the background to no longer match the token.
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

/// Tablet layout rail: width 96, background `surfaceContainer`, indicator 56x32.
///
/// The design mockup places a square with a microphone icon above the destinations and a palette button below them without
/// specifying their actions. An icon without an action is worse than no icon, so both lead to where
/// the corresponding feature belongs: microphone to the Record screen, palette to Settings where theme
/// selection resides. Decision documented in report.
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
      // `margin-top:auto` from mockup: button stays at the bottom edge of the rail regardless
      // of how much space remains above it.
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

/// Square rail button: 56x56, radius 16, centered icon.
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
