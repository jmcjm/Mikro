import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/theme/app_theme.dart';
import 'package:mikro/core/theme/theme_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
}

void main() {
  group('buildTheme', () {
    test('paleta md3 w wersji jasnej odwzorowuje tokeny z designu', () {
      final scheme =
          buildTheme(palette: AppPalette.md3, brightness: Brightness.light).colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, const Color(0xFF65558F));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.primaryContainer, const Color(0xFFE9DDFF));
      expect(scheme.onPrimaryContainer, const Color(0xFF21005D));
      expect(scheme.secondaryContainer, const Color(0xFFE8DEF8));
      expect(scheme.onSecondaryContainer, const Color(0xFF1D192B));
      expect(scheme.surface, const Color(0xFFFEF7FF));
      expect(scheme.surfaceContainerLow, const Color(0xFFF7F2FA));
      expect(scheme.surfaceContainer, const Color(0xFFF3EDF7));
      expect(scheme.surfaceContainerHigh, const Color(0xFFECE6F0));
      expect(scheme.onSurface, const Color(0xFF1D1B20));
      expect(scheme.onSurfaceVariant, const Color(0xFF49454F));
      expect(scheme.outline, const Color(0xFF79747E));
      expect(scheme.outlineVariant, const Color(0xFFCAC4D0));
      expect(scheme.error, const Color(0xFFB3261E));
      expect(scheme.onError, const Color(0xFFFFFFFF));
      expect(scheme.errorContainer, const Color(0xFFF9DEDC));
      expect(scheme.onErrorContainer, const Color(0xFF410E0B));
      expect(scheme.inverseSurface, const Color(0xFF322F35));
      expect(scheme.onInverseSurface, const Color(0xFFF5EFF7));
    });

    test('paleta md3 w wersji ciemnej odwzorowuje tokeny z designu', () {
      final scheme =
          buildTheme(palette: AppPalette.md3, brightness: Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFFCFBCFF));
      expect(scheme.onPrimary, const Color(0xFF36275D));
      expect(scheme.primaryContainer, const Color(0xFF4D3D75));
      expect(scheme.onPrimaryContainer, const Color(0xFFE9DDFF));
      expect(scheme.secondaryContainer, const Color(0xFF4A4458));
      expect(scheme.onSecondaryContainer, const Color(0xFFE8DEF8));
      expect(scheme.surface, const Color(0xFF141218));
      expect(scheme.surfaceContainerLow, const Color(0xFF1D1B20));
      expect(scheme.surfaceContainer, const Color(0xFF211F26));
      expect(scheme.surfaceContainerHigh, const Color(0xFF2B2930));
      expect(scheme.onSurface, const Color(0xFFE6E0E9));
      expect(scheme.onSurfaceVariant, const Color(0xFFCAC4D0));
      expect(scheme.outline, const Color(0xFF938F99));
      expect(scheme.outlineVariant, const Color(0xFF49454F));
      expect(scheme.error, const Color(0xFFF2B8B5));
      expect(scheme.onError, const Color(0xFF601410));
      expect(scheme.errorContainer, const Color(0xFF8C1D18));
      expect(scheme.onErrorContainer, const Color(0xFFF9DEDC));
    });

    test('motyw jest Material 3 i uzupelnia role, ktorych design nie podaje', () {
      final light = buildTheme(palette: AppPalette.md3, brightness: Brightness.light);
      expect(light.useMaterial3, isTrue);
      // Design nie definiuje secondary/onSecondary — musza byc czyms sensownym, nie null-em
      // ani przypadkiem tym samym co primary.
      expect(light.colorScheme.secondary, isNot(light.colorScheme.primary));
      expect(light.colorScheme.onSecondary, isNotNull);
    });
  });

  group('providery motywu', () {
    test('domyslnie system i md3, gdy nic nie zapisano', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });

    test('odczytuje zapisane wartosci z preferencji', () async {
      final container =
          await containerWith({'theme_mode': 'dark', 'theme_palette': 'md3'});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });

    test('zapis trybu robi rundtrip przez preferencje', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(first.dispose);

      await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(first.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');

      // Nowy kontener na tych samych preferencjach — jak po restarcie aplikacji.
      final second =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(second.dispose);
      expect(second.read(themeModeProvider), ThemeMode.dark);
    });

    test('nieznana wartosc w preferencjach nie wywraca startu', () async {
      final container = await containerWith(
          {'theme_mode': 'zupelnie-nie-tryb', 'theme_palette': 'nie-ma-takiej'});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });
  });
}
