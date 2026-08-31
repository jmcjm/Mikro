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
    test('md3 light palette reproduces tokens from design', () {
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

    test('md3 dark palette reproduces tokens from design', () {
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

    test('theme is Material 3 and fills in roles not provided by design', () {
      final light = buildTheme(palette: AppPalette.md3, brightness: Brightness.light);
      expect(light.useMaterial3, isTrue);
      // Design does not define secondary/onSecondary — they must be reasonable, not null
      // or accidentally identical to primary.
      expect(light.colorScheme.secondary, isNot(light.colorScheme.primary));
      expect(light.colorScheme.onSecondary, isNotNull);
    });
  });

  group('theme providers', () {
    test('defaults to system and md3 when nothing is stored', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });

    test('reads stored values from preferences', () async {
      final container =
          await containerWith({'theme_mode': 'dark', 'theme_palette': 'md3'});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });

    test('saving mode roundtrips through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(first.dispose);

      await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(first.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');

      // New container on same preferences — like after app restart.
      final second =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(second.dispose);
      expect(second.read(themeModeProvider), ThemeMode.dark);
    });

    test('unknown value in preferences does not crash startup', () async {
      final container = await containerWith(
          {'theme_mode': 'zupelnie-nie-tryb', 'theme_palette': 'nie-ma-takiej'});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });

    test('value of wrong type under theme key also does not crash startup', () async {
      // Not hypothetical: app downgrade or key collision leaves a number or boolean under the same
      // key name. Typed getString() would then throw in the very first frame
      // of building theme, before anything can render — white screen without
      // escape path, since theme is read on every startup.
      final container = await containerWith({'theme_mode': 7, 'theme_palette': true});
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themePaletteProvider), AppPalette.md3);
    });
  });

  group('palettes from design', () {
    // Tokens transcribed from THEMES map in design/Mikro-MD3.dc.html (lines 606-612). Each expect
    // corresponds to one key in that map, making source auditing mechanical.
    test('dracula reproduces full set of tokens from THEMES map', () {
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

    test('nord reproduces full set of tokens from THEMES map', () {
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

    test('gruvbox reproduces full set of tokens from THEMES map', () {
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

    // Design provides ONE token set each for dracula/nord/gruvbox and these are dark sets.
    // However MikroApp always builds both variants (theme and darkTheme), so light variant of these
    // palettes must be defined. We return the same dark set rather than synthesizing
    // a light one not defined in design.
    test('dark palettes produce same scheme regardless of requested brightness', () {
      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        final asLight = buildTheme(palette: palette, brightness: Brightness.light).colorScheme;
        final asDark = buildTheme(palette: palette, brightness: Brightness.dark).colorScheme;

        expect(asLight.brightness, Brightness.dark, reason: '$palette is a dark palette');
        expect(asLight.primary, asDark.primary, reason: '$palette');
        expect(asLight.surface, asDark.surface, reason: '$palette');
        expect(asLight.onSurface, asDark.onSurface, reason: '$palette');
      }
    });

    // Roles NOT named in design (secondary, onSecondary, surfaceTint...) come from
    // ColorScheme.fromSeed. If every palette seeded from same seed as md3, purple accent
    // from baseline would leak into Dracula, Nord and Gruvbox via those roles.
    test('roles outside design do not inherit md3 seed', () {
      final md3 = buildTheme(palette: AppPalette.md3, brightness: Brightness.dark).colorScheme;

      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        final scheme = buildTheme(palette: palette, brightness: Brightness.dark).colorScheme;

        expect(scheme.secondary, isNot(md3.secondary), reason: '$palette: secondary from md3');
        expect(scheme.onSecondary, isNot(md3.onSecondary), reason: '$palette: onSecondary from md3');
        expect(scheme.surfaceTint, isNot(md3.surfaceTint), reason: '$palette: surfaceTint from md3');
      }
    });

    test('md3 still has separate light and dark variants', () {
      final light = buildTheme(palette: AppPalette.md3, brightness: Brightness.light).colorScheme;
      final dark = buildTheme(palette: AppPalette.md3, brightness: Brightness.dark).colorScheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.surface, isNot(dark.surface));
    });

    // Preview swatches on theme selector cards — values directly from mockup cards.
    test('palette preview returns color triplet from mockup cards', () {
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

  group('palette persistence', () {
    test('selecting each new palette roundtrips through preferences', () async {
      for (final palette in [AppPalette.dracula, AppPalette.nord, AppPalette.gruvbox]) {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final first =
            ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
        addTearDown(first.dispose);

        await first.read(themePaletteProvider.notifier).setPalette(palette);
        expect(first.read(themePaletteProvider), palette);
        expect(prefs.getString('theme_palette'), palette.name);

        // New container on same preferences — like after app restart.
        final second =
            ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
        addTearDown(second.dispose);
        expect(second.read(themePaletteProvider), palette,
            reason: '$palette did not survive restart');
      }
    });

    test('palette names in preferences are a stable on-disk format', () {
      expect(AppPalette.values.map((p) => p.name).toList(),
          ['md3', 'dracula', 'nord', 'gruvbox']);
    });
  });
}
