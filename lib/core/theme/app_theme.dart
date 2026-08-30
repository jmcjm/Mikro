import 'package:flutter/material.dart';

/// Available colour palettes. The design source (`design/Mikro-MD3.dc.html`) defines five
/// token sets; D1a ships the MD3 baseline and leaves the enum open — the settings lane adds
/// Dracula, Nord and Gruvbox by extending [_tokensFor] and this enum, without touching
/// [buildTheme] itself.
enum AppPalette { md3 }

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

_PaletteTokens _tokensFor(AppPalette palette, Brightness brightness) =>
    switch ((palette, brightness)) {
      (AppPalette.md3, Brightness.light) => _md3Light,
      (AppPalette.md3, Brightness.dark) => _md3Dark,
    };

Color _seedFor(AppPalette palette) => switch (palette) {
      AppPalette.md3 => _md3Seed,
    };

/// Builds the Material 3 theme for [palette] in [brightness].
///
/// Every role the design names is applied verbatim. Roles it stays silent about (secondary,
/// onTertiary, scrim, shadow…) come from `ColorScheme.fromSeed`, so the scheme is complete and
/// internally consistent instead of being padded with guesses.
ThemeData buildTheme({required AppPalette palette, required Brightness brightness}) {
  final tokens = _tokensFor(palette, brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedFor(palette),
    brightness: brightness,
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
