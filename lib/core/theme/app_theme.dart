import 'package:flutter/material.dart';

/// Monospace font family bundled with the app (`pubspec.yaml`, `fonts` section). The design renders
/// technical values in this font: endpoints, model names, timestamps, and recording parameters. The name must
/// match `family:` in pubspec exactly — Flutter matches font families literally and falls back silently
/// to the default font on typos, so screens reference this constant instead of raw string literals.
/// Verified by test.
const monoFontFamily = 'RobotoMono';

/// Fallback list in case the bundled font family is unavailable (e.g. stripped build):
/// better to fall back to system monospace than proportional default font, preserving digit column alignment.
const monoFontFallback = <String>['monospace'];

/// Available colour palettes. The design source (`design/Mikro-MD3.dc.html`) defines five
/// token sets in its `THEMES` map: `light` and `dark` form the MD3 baseline, while `dracula`,
/// `nord` and `gruvbox` are single, dark-only sets — see [_isDarkOnly].
///
/// The enum value name is the on-disk format used by `themePaletteProvider`, so renaming one
/// silently resets the user's choice. Pinned by tests.
enum AppPalette { md3, dracula, nord, gruvbox }

/// Colour roles taken verbatim from the design's `THEMES` map. Field names follow Flutter's
/// [ColorScheme] roles; the design's short keys are noted next to each value so the mapping
/// stays auditable against the source file.
@immutable
class _PaletteTokens {
  const _PaletteTokens({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color inverseSurface;
  final Color onInverseSurface;
}

/// Seed used to fill in the roles the design does not name (secondary, onTertiary, scrim…).
const _md3Seed = Color(0xFF65558F);

const _md3Light = _PaletteTokens(
  primary: Color(0xFF65558F), // p
  onPrimary: Color(0xFFFFFFFF), // op
  primaryContainer: Color(0xFFE9DDFF), // pc
  onPrimaryContainer: Color(0xFF21005D), // opc
  secondaryContainer: Color(0xFFE8DEF8), // s2c
  onSecondaryContainer: Color(0xFF1D192B), // os2c
  tertiary: Color(0xFF7D5260), // t
  tertiaryContainer: Color(0xFFFFD8E4), // tc
  onTertiaryContainer: Color(0xFF31111D), // otc
  surface: Color(0xFFFEF7FF), // sf
  surfaceContainerLow: Color(0xFFF7F2FA), // sc1
  surfaceContainer: Color(0xFFF3EDF7), // sc2
  surfaceContainerHigh: Color(0xFFECE6F0), // sc3
  onSurface: Color(0xFF1D1B20), // on
  onSurfaceVariant: Color(0xFF49454F), // onv
  outline: Color(0xFF79747E), // ol
  outlineVariant: Color(0xFFCAC4D0), // olv
  error: Color(0xFFB3261E), // err
  onError: Color(0xFFFFFFFF), // onerr
  errorContainer: Color(0xFFF9DEDC), // errc
  onErrorContainer: Color(0xFF410E0B), // onerrc
  inverseSurface: Color(0xFF322F35), // inv
  onInverseSurface: Color(0xFFF5EFF7), // oninv
);

const _md3Dark = _PaletteTokens(
  primary: Color(0xFFCFBCFF), // p
  onPrimary: Color(0xFF36275D), // op
  primaryContainer: Color(0xFF4D3D75), // pc
  onPrimaryContainer: Color(0xFFE9DDFF), // opc
  secondaryContainer: Color(0xFF4A4458), // s2c
  onSecondaryContainer: Color(0xFFE8DEF8), // os2c
  tertiary: Color(0xFFEFB8C8), // t
  tertiaryContainer: Color(0xFF633B48), // tc
  onTertiaryContainer: Color(0xFFFFD8E4), // otc
  surface: Color(0xFF141218), // sf
  surfaceContainerLow: Color(0xFF1D1B20), // sc1
  surfaceContainer: Color(0xFF211F26), // sc2
  surfaceContainerHigh: Color(0xFF2B2930), // sc3
  onSurface: Color(0xFFE6E0E9), // on
  onSurfaceVariant: Color(0xFFCAC4D0), // onv
  outline: Color(0xFF938F99), // ol
  outlineVariant: Color(0xFF49454F), // olv
  error: Color(0xFFF2B8B5), // err
  onError: Color(0xFF601410), // onerr
  errorContainer: Color(0xFF8C1D18), // errc
  onErrorContainer: Color(0xFFF9DEDC), // onerrc
  inverseSurface: Color(0xFFE6E0E9), // inv
  onInverseSurface: Color(0xFF322F35), // oninv
);

/// Dracula, Nord and Gruvbox each ship a single dark token set. Their seed is the palette's own
/// `primary`, so the roles the design leaves unnamed stay in the same colour family.
const _draculaSeed = Color(0xFFBD93F9);
const _nordSeed = Color(0xFF88C0D0);
const _gruvboxSeed = Color(0xFFD3869B);

const _dracula = _PaletteTokens(
  primary: Color(0xFFBD93F9), // p
  onPrimary: Color(0xFF282A36), // op
  primaryContainer: Color(0xFF44475A), // pc
  onPrimaryContainer: Color(0xFFF8F8F2), // opc
  secondaryContainer: Color(0xFF3C3F51), // s2c
  onSecondaryContainer: Color(0xFFF8F8F2), // os2c
  tertiary: Color(0xFFFF79C6), // t
  tertiaryContainer: Color(0xFF4A2F42), // tc
  onTertiaryContainer: Color(0xFFFFD7EE), // otc
  surface: Color(0xFF282A36), // sf
  surfaceContainerLow: Color(0xFF21222C), // sc1
  surfaceContainer: Color(0xFF2E303E), // sc2
  surfaceContainerHigh: Color(0xFF383A4A), // sc3
  onSurface: Color(0xFFF8F8F2), // on
  onSurfaceVariant: Color(0xFFBFC3D9), // onv
  outline: Color(0xFF6272A4), // ol
  outlineVariant: Color(0xFF44475A), // olv
  error: Color(0xFFFF5555), // err
  onError: Color(0xFF2A1414), // onerr
  errorContainer: Color(0xFF4E2429), // errc
  onErrorContainer: Color(0xFFFFD9D9), // onerrc
  inverseSurface: Color(0xFFF8F8F2), // inv
  onInverseSurface: Color(0xFF282A36), // oninv
);

const _nord = _PaletteTokens(
  primary: Color(0xFF88C0D0), // p
  onPrimary: Color(0xFF2E3440), // op
  primaryContainer: Color(0xFF3B4252), // pc
  onPrimaryContainer: Color(0xFFECEFF4), // opc
  secondaryContainer: Color(0xFF434C5E), // s2c
  onSecondaryContainer: Color(0xFFECEFF4), // os2c
  tertiary: Color(0xFFB48EAD), // t
  tertiaryContainer: Color(0xFF463C4B), // tc
  onTertiaryContainer: Color(0xFFF0DCEE), // otc
  surface: Color(0xFF2E3440), // sf
  surfaceContainerLow: Color(0xFF292E39), // sc1
  surfaceContainer: Color(0xFF343B49), // sc2
  surfaceContainerHigh: Color(0xFF3E4756), // sc3
  onSurface: Color(0xFFECEFF4), // on
  onSurfaceVariant: Color(0xFFD8DEE9), // onv
  outline: Color(0xFF4C566A), // ol
  outlineVariant: Color(0xFF434C5E), // olv
  error: Color(0xFFBF616A), // err
  onError: Color(0xFF2A1518), // onerr
  errorContainer: Color(0xFF4A2A2E), // errc
  onErrorContainer: Color(0xFFF6D8DB), // onerrc
  inverseSurface: Color(0xFFECEFF4), // inv
  onInverseSurface: Color(0xFF2E3440), // oninv
);

const _gruvbox = _PaletteTokens(
  primary: Color(0xFFD3869B), // p
  onPrimary: Color(0xFF282828), // op
  primaryContainer: Color(0xFF503541), // pc
  onPrimaryContainer: Color(0xFFFBE9EF), // opc
  secondaryContainer: Color(0xFF504945), // s2c
  onSecondaryContainer: Color(0xFFEBDBB2), // os2c
  tertiary: Color(0xFFFABD2F), // t
  tertiaryContainer: Color(0xFF4C3A17), // tc
  onTertiaryContainer: Color(0xFFFFE9B0), // otc
  surface: Color(0xFF282828), // sf
  surfaceContainerLow: Color(0xFF232323), // sc1
  surfaceContainer: Color(0xFF32302F), // sc2
  surfaceContainerHigh: Color(0xFF3C3836), // sc3
  onSurface: Color(0xFFEBDBB2), // on
  onSurfaceVariant: Color(0xFFD5C4A1), // onv
  outline: Color(0xFF665C54), // ol
  outlineVariant: Color(0xFF504945), // olv
  error: Color(0xFFFB4934), // err
  onError: Color(0xFF2A1210), // onerr
  errorContainer: Color(0xFF4E241E), // errc
  onErrorContainer: Color(0xFFFFD6CF), // onerrc
  inverseSurface: Color(0xFFEBDBB2), // inv
  onInverseSurface: Color(0xFF282828), // oninv
);

/// Palettes the design defines with a single, dark token set. [buildTheme] therefore ignores the
/// requested brightness for them: `MikroApp` always builds both `theme` and `darkTheme`, so the
/// light slot has to hold something, and returning the dark set is the only answer the design
/// actually supports. Inventing a light variant would put colours on screen that the source
/// never specifies.
bool _isDarkOnly(AppPalette palette) => switch (palette) {
      AppPalette.md3 => false,
      AppPalette.dracula || AppPalette.nord || AppPalette.gruvbox => true,
    };

/// Preview dots shown on the theme cards, taken straight from the "Motyw" section of the design.
/// They are not derived from the roles: the design picks a different pair per card (baseline uses
/// primary + primaryContainer, Dracula and Gruvbox use primary + tertiary), and Nord's middle dot
/// is `#5E81AC`, a colour that appears on the card but not in the `THEMES` map at all.
const _md3LightSwatch = [Color(0xFF65558F), Color(0xFFE9DDFF), Color(0xFFFEF7FF)];
const _md3DarkSwatch = [Color(0xFFCFBCFF), Color(0xFF4D3D75), Color(0xFF141218)];
const _draculaSwatch = [Color(0xFFBD93F9), Color(0xFFFF79C6), Color(0xFF282A36)];
const _nordSwatch = [Color(0xFF88C0D0), Color(0xFF5E81AC), Color(0xFF2E3440)];
const _gruvboxSwatch = [Color(0xFFD3869B), Color(0xFFFABD2F), Color(0xFF282828)];

/// The three preview colours for [palette]'s card in the settings screen.
List<Color> paletteSwatch(AppPalette palette, Brightness brightness) => switch (palette) {
      AppPalette.md3 =>
        brightness == Brightness.light ? _md3LightSwatch : _md3DarkSwatch,
      AppPalette.dracula => _draculaSwatch,
      AppPalette.nord => _nordSwatch,
      AppPalette.gruvbox => _gruvboxSwatch,
    };

_PaletteTokens _tokensFor(AppPalette palette, Brightness brightness) =>
    switch ((palette, brightness)) {
      (AppPalette.md3, Brightness.light) => _md3Light,
      (AppPalette.md3, Brightness.dark) => _md3Dark,
      // Brightness is irrelevant here — these palettes are dark-only, see [_isDarkOnly].
      (AppPalette.dracula, _) => _dracula,
      (AppPalette.nord, _) => _nord,
      (AppPalette.gruvbox, _) => _gruvbox,
    };

Color _seedFor(AppPalette palette) => switch (palette) {
      AppPalette.md3 => _md3Seed,
      AppPalette.dracula => _draculaSeed,
      AppPalette.nord => _nordSeed,
      AppPalette.gruvbox => _gruvboxSeed,
    };

/// Builds the Material 3 theme for [palette] in [brightness].
///
/// Every role the design names is applied verbatim. Roles it stays silent about (secondary,
/// onTertiary, scrim, shadow…) come from `ColorScheme.fromSeed`, so the scheme is complete and
/// internally consistent instead of being padded with guesses.
ThemeData buildTheme({required AppPalette palette, required Brightness brightness}) {
  // Dark-only palettes pin the brightness, so their scheme stays internally consistent: the roles
  // the design does not name are generated against the same brightness as the ones it does.
  final effective = _isDarkOnly(palette) ? Brightness.dark : brightness;
  final tokens = _tokensFor(palette, effective);
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedFor(palette),
    brightness: effective,
  ).copyWith(
    primary: tokens.primary,
    onPrimary: tokens.onPrimary,
    primaryContainer: tokens.primaryContainer,
    onPrimaryContainer: tokens.onPrimaryContainer,
    secondaryContainer: tokens.secondaryContainer,
    onSecondaryContainer: tokens.onSecondaryContainer,
    tertiary: tokens.tertiary,
    tertiaryContainer: tokens.tertiaryContainer,
    onTertiaryContainer: tokens.onTertiaryContainer,
    surface: tokens.surface,
    surfaceContainerLow: tokens.surfaceContainerLow,
    surfaceContainer: tokens.surfaceContainer,
    surfaceContainerHigh: tokens.surfaceContainerHigh,
    onSurface: tokens.onSurface,
    onSurfaceVariant: tokens.onSurfaceVariant,
    outline: tokens.outline,
    outlineVariant: tokens.outlineVariant,
    error: tokens.error,
    onError: tokens.onError,
    errorContainer: tokens.errorContainer,
    onErrorContainer: tokens.onErrorContainer,
    inverseSurface: tokens.inverseSurface,
    onInverseSurface: tokens.onInverseSurface,
  );

  return ThemeData(useMaterial3: true, colorScheme: scheme);
}
