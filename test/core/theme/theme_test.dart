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

    test('wartosc obcego typu pod kluczem motywu tez nie wywraca startu', () async {
      // Nie hipotetyczne: downgrade aplikacji albo kolizja klucza zostawia pod tym samym
      // nazwiskiem liczbe czy flage. Typowany getString() rzucilby wtedy w pierwszej klatce
      // budowania motywu, czyli zanim cokolwiek zdazy sie narysowac — bialy ekran bez
      // sciezki wyjscia, bo motyw czyta sie przy kazdym starcie.
      final container = await containerWith({'theme_mode': 7, 'theme_palette': true});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });
  });

  group('palety z designu', () {
    // Tokeny przepisane z mapy THEMES w design/Mikro-MD3.dc.html (linie 606-612). Kazdy expect
    // odpowiada jednemu kluczowi tej mapy, zeby audyt wobec zrodla byl mechaniczny.
    test('dracula odwzorowuje komplet tokenow z mapy THEMES', () {
      final scheme =
          buildTheme(palette: AppPalette.dracula, brightness: Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFFBD93F9)); // p
      expect(scheme.onPrimary, const Color(0xFF282A36)); // op
      expect(scheme.primaryContainer, const Color(0xFF44475A)); // pc
      expect(scheme.onPrimaryContainer, const Color(0xFFF8F8F2)); // opc
      expect(scheme.secondaryContainer, const Color(0xFF3C3F51)); // s2c
      expect(scheme.onSecondaryContainer, const Color(0xFFF8F8F2)); // os2c
      expect(scheme.tertiary, const Color(0xFFFF79C6)); // t
      expect(scheme.tertiaryContainer, const Color(0xFF4A2F42)); // tc
      expect(scheme.onTertiaryContainer, const Color(0xFFFFD7EE)); // otc
      expect(scheme.surface, const Color(0xFF282A36)); // sf
      expect(scheme.surfaceContainerLow, const Color(0xFF21222C)); // sc1
      expect(scheme.surfaceContainer, const Color(0xFF2E303E)); // sc2
      expect(scheme.surfaceContainerHigh, const Color(0xFF383A4A)); // sc3
      expect(scheme.onSurface, const Color(0xFFF8F8F2)); // on
      expect(scheme.onSurfaceVariant, const Color(0xFFBFC3D9)); // onv
      expect(scheme.outline, const Color(0xFF6272A4)); // ol
      expect(scheme.outlineVariant, const Color(0xFF44475A)); // olv
      expect(scheme.error, const Color(0xFFFF5555)); // err
      expect(scheme.onError, const Color(0xFF2A1414)); // onerr
      expect(scheme.errorContainer, const Color(0xFF4E2429)); // errc
      expect(scheme.onErrorContainer, const Color(0xFFFFD9D9)); // onerrc
      expect(scheme.inverseSurface, const Color(0xFFF8F8F2)); // inv
      expect(scheme.onInverseSurface, const Color(0xFF282A36)); // oninv
    });

    test('nord odwzorowuje komplet tokenow z mapy THEMES', () {
      final scheme =
          buildTheme(palette: AppPalette.nord, brightness: Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFF88C0D0)); // p
      expect(scheme.onPrimary, const Color(0xFF2E3440)); // op
      expect(scheme.primaryContainer, const Color(0xFF3B4252)); // pc
      expect(scheme.onPrimaryContainer, const Color(0xFFECEFF4)); // opc
      expect(scheme.secondaryContainer, const Color(0xFF434C5E)); // s2c
      expect(scheme.onSecondaryContainer, const Color(0xFFECEFF4)); // os2c
      expect(scheme.tertiary, const Color(0xFFB48EAD)); // t
      expect(scheme.tertiaryContainer, const Color(0xFF463C4B)); // tc
      expect(scheme.onTertiaryContainer, const Color(0xFFF0DCEE)); // otc
      expect(scheme.surface, const Color(0xFF2E3440)); // sf
      expect(scheme.surfaceContainerLow, const Color(0xFF292E39)); // sc1
      expect(scheme.surfaceContainer, const Color(0xFF343B49)); // sc2
      expect(scheme.surfaceContainerHigh, const Color(0xFF3E4756)); // sc3
      expect(scheme.onSurface, const Color(0xFFECEFF4)); // on
      expect(scheme.onSurfaceVariant, const Color(0xFFD8DEE9)); // onv
      expect(scheme.outline, const Color(0xFF4C566A)); // ol
      expect(scheme.outlineVariant, const Color(0xFF434C5E)); // olv
      expect(scheme.error, const Color(0xFFBF616A)); // err
      expect(scheme.onError, const Color(0xFF2A1518)); // onerr
      expect(scheme.errorContainer, const Color(0xFF4A2A2E)); // errc
      expect(scheme.onErrorContainer, const Color(0xFFF6D8DB)); // onerrc
      expect(scheme.inverseSurface, const Color(0xFFECEFF4)); // inv
      expect(scheme.onInverseSurface, const Color(0xFF2E3440)); // oninv
    });

    test('gruvbox odwzorowuje komplet tokenow z mapy THEMES', () {
      final scheme =
          buildTheme(palette: AppPalette.gruvbox, brightness: Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFFD3869B)); // p
      expect(scheme.onPrimary, const Color(0xFF282828)); // op
      expect(scheme.primaryContainer, const Color(0xFF503541)); // pc
      expect(scheme.onPrimaryContainer, const Color(0xFFFBE9EF)); // opc
      expect(scheme.secondaryContainer, const Color(0xFF504945)); // s2c
      expect(scheme.onSecondaryContainer, const Color(0xFFEBDBB2)); // os2c
      expect(scheme.tertiary, const Color(0xFFFABD2F)); // t
      expect(scheme.tertiaryContainer, const Color(0xFF4C3A17)); // tc
      expect(scheme.onTertiaryContainer, const Color(0xFFFFE9B0)); // otc
      expect(scheme.surface, const Color(0xFF282828)); // sf
      expect(scheme.surfaceContainerLow, const Color(0xFF232323)); // sc1
      expect(scheme.surfaceContainer, const Color(0xFF32302F)); // sc2
      expect(scheme.surfaceContainerHigh, const Color(0xFF3C3836)); // sc3
      expect(scheme.onSurface, const Color(0xFFEBDBB2)); // on
      expect(scheme.onSurfaceVariant, const Color(0xFFD5C4A1)); // onv
      expect(scheme.outline, const Color(0xFF665C54)); // ol
      expect(scheme.outlineVariant, const Color(0xFF504945)); // olv
      expect(scheme.error, const Color(0xFFFB4934)); // err
      expect(scheme.onError, const Color(0xFF2A1210)); // onerr
      expect(scheme.errorContainer, const Color(0xFF4E241E)); // errc
      expect(scheme.onErrorContainer, const Color(0xFFFFD6CF)); // onerrc
      expect(scheme.inverseSurface, const Color(0xFFEBDBB2)); // inv
      expect(scheme.onInverseSurface, const Color(0xFF282828)); // oninv
    });

    // Design daje dla dracula/nord/gruvbox po JEDNYM zestawie tokenow i sa to zestawy ciemne.
    // MikroApp buduje jednak zawsze oba warianty (theme i darkTheme), wiec jasny wariant tych
    // palet musi byc czyms zdefiniowanym. Zwracamy ten sam, ciemny zestaw zamiast dogenerowywac
    // jasny, ktorego design nie definiuje.
    test('palety ciemne daja ten sam schemat niezaleznie od zadanej jasnosci', () {
      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        final asLight = buildTheme(palette: palette, brightness: Brightness.light).colorScheme;
        final asDark = buildTheme(palette: palette, brightness: Brightness.dark).colorScheme;

        expect(asLight.brightness, Brightness.dark, reason: '$palette jest paleta ciemna');
        expect(asLight.primary, asDark.primary, reason: '$palette');
        expect(asLight.surface, asDark.surface, reason: '$palette');
        expect(asLight.onSurface, asDark.onSurface, reason: '$palette');
      }
    });

    // Role, ktorych design NIE nazywa (secondary, onSecondary, surfaceTint...), pochodza z
    // ColorScheme.fromSeed. Gdyby kazda paleta siala tym samym ziarnem co md3, fioletowy akcent
    // baseline'u przeciekalby do Draculi, Norda i Gruvboxa wlasnie tymi rolami.
    test('role spoza designu nie dziedzicza ziarna md3', () {
      final md3 = buildTheme(palette: AppPalette.md3, brightness: Brightness.dark).colorScheme;

      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        final scheme = buildTheme(palette: palette, brightness: Brightness.dark).colorScheme;

        expect(scheme.secondary, isNot(md3.secondary), reason: '$palette: secondary z md3');
        expect(scheme.onSecondary, isNot(md3.onSecondary), reason: '$palette: onSecondary z md3');
        expect(scheme.surfaceTint, isNot(md3.surfaceTint), reason: '$palette: surfaceTint z md3');
      }
    });

    test('md3 nadal ma osobny wariant jasny i ciemny', () {
      final light = buildTheme(palette: AppPalette.md3, brightness: Brightness.light).colorScheme;
      final dark = buildTheme(palette: AppPalette.md3, brightness: Brightness.dark).colorScheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.surface, isNot(dark.surface));
    });

    // Kropki podgladu na kartach wyboru motywu — wartosci wprost z kart w makiecie.
    test('podglad palety zwraca trojke kolorow z kart makiety', () {
      expect(paletteSwatch(AppPalette.md3, Brightness.light), const [
        Color(0xFF65558F),
        Color(0xFFE9DDFF),
        Color(0xFFFEF7FF),
      ]);
      expect(paletteSwatch(AppPalette.md3, Brightness.dark), const [
        Color(0xFFCFBCFF),
        Color(0xFF4D3D75),
        Color(0xFF141218),
      ]);
      expect(paletteSwatch(AppPalette.dracula, Brightness.dark), const [
        Color(0xFFBD93F9),
        Color(0xFFFF79C6),
        Color(0xFF282A36),
      ]);
      expect(paletteSwatch(AppPalette.nord, Brightness.dark), const [
        Color(0xFF88C0D0),
        Color(0xFF5E81AC),
        Color(0xFF2E3440),
      ]);
      expect(paletteSwatch(AppPalette.gruvbox, Brightness.dark), const [
        Color(0xFFD3869B),
        Color(0xFFFABD2F),
        Color(0xFF282828),
      ]);
    });
  });

  group('persystencja palet', () {
    test('wybor kazdej nowej palety robi rundtrip przez preferencje', () async {
      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final first =
            ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
        addTearDown(first.dispose);

        await first.read(themePaletteProvider.notifier).setPalette(palette);
        expect(first.read(themePaletteProvider), palette);
        expect(prefs.getString('theme_palette'), palette.name);

        // Nowy kontener na tych samych preferencjach — jak po restarcie aplikacji.
        final second =
            ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
        addTearDown(second.dispose);
        expect(second.read(themePaletteProvider), palette,
            reason: '$palette nie przetrwala restartu');
      }
    });

    test('nazwy palet w preferencjach sa stabilnym formatem na dysku', () {
      expect(AppPalette.values.map((p) => p.name).toList(),
          ['md3', 'dracula', 'nord', 'gruvbox']);
    });
  });
}
