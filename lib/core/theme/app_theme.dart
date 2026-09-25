import 'package:flutter/material.dart';

import 'accent_palette.dart';

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
/// `nord` and `gruvbox` are single, dark-only sets — see [_fixedBrightness]. The Catppuccin
/// flavours and Solarized come from their own published palettes (see the note above their
/// tokens): Latte is light-only, Frappé, Macchiato and Mocha dark-only, Solarized has both.
///
/// The enum value name is the on-disk format used by `themePaletteProvider`, so renaming one
/// silently resets the user's choice — new palettes are appended. Pinned by tests.
enum AppPalette {
  md3,
  dracula,
  nord,
  gruvbox,
  catppuccinLatte,
  catppuccinFrappe,
  catppuccinMacchiato,
  catppuccinMocha,
  solarized,
}

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
// Catppuccin and Solarized come from their published palettes rather than the design file:
// Catppuccin roles follow its style guide (base = background pane, mantle/crust = secondary
// panes, surface0-2 = surface elements, text/subtext = copy, overlay0 = inactive border, mauve
// as the accent, base on accents), hex values from catppuccin/palette. Container colours the
// guides do not name are the accent mixed 20-25% over the background, like the design does for
// Dracula, Nord and Gruvbox.
//
// Solarized follows Ethan Schoonover's table: base03/base3 background, base02/base2 background
// highlights, base01/base1 secondary content. One deviation: text uses the "emphasized" tone
// (base1 dark / base01 light) and labels the "body" tone, because body text on the light
// background (base00 on base3) falls short of comfortable contrast in a UI at small sizes.
/// Catppuccin Latte.
const _catppuccinLatte = _PaletteTokens(
  primary: Color(0xFF8839EF), // mauve
  onPrimary: Color(0xFFEFF1F5), // base — "On Accent"
  primaryContainer: Color(0xFFBCC0CC), // surface1
  onPrimaryContainer: Color(0xFF4C4F69), // text
  secondaryContainer: Color(0xFFCCD0DA), // surface0
  onSecondaryContainer: Color(0xFF4C4F69), // text
  tertiary: Color(0xFFEA76CB), // pink
  tertiaryContainer: Color(0xFFEED2EA), // pink 25% over base
  onTertiaryContainer: Color(0xFF4C4F69), // text
  surface: Color(0xFFEFF1F5), // base — "Background Pane"
  surfaceContainerLow: Color(0xFFE6E9EF), // mantle — "Secondary Panes"
  surfaceContainer: Color(0xFFDCE0E8), // crust — "Secondary Panes"
  surfaceContainerHigh: Color(0xFFCCD0DA), // surface0 — "Surface Elements"
  onSurface: Color(0xFF4C4F69), // text — "Body Copy"
  onSurfaceVariant: Color(0xFF6C6F85), // subtext0 — "Sub-Headlines, Labels"
  outline: Color(0xFF9CA0B0), // overlay0 — "Inactive Border"
  outlineVariant: Color(0xFFBCC0CC), // surface1
  error: Color(0xFFD20F39), // red — "Errors"
  onError: Color(0xFFEFF1F5), // base
  errorContainer: Color(0xFFE8B8C6), // red 25% over base
  onErrorContainer: Color(0xFF4C4F69), // text
  inverseSurface: Color(0xFF4C4F69), // text
  onInverseSurface: Color(0xFFEFF1F5), // base
);

/// Catppuccin Frappé.
const _catppuccinFrappe = _PaletteTokens(
  primary: Color(0xFFCA9EE6), // mauve
  onPrimary: Color(0xFF303446), // base — "On Accent"
  primaryContainer: Color(0xFF51576D), // surface1
  onPrimaryContainer: Color(0xFFC6D0F5), // text
  secondaryContainer: Color(0xFF414559), // surface0
  onSecondaryContainer: Color(0xFFC6D0F5), // text
  tertiary: Color(0xFFF4B8E4), // pink
  tertiaryContainer: Color(0xFF61556E), // pink 25% over base
  onTertiaryContainer: Color(0xFFC6D0F5), // text
  surface: Color(0xFF303446), // base — "Background Pane"
  surfaceContainerLow: Color(0xFF292C3C), // mantle — "Secondary Panes"
  surfaceContainer: Color(0xFF232634), // crust — "Secondary Panes"
  surfaceContainerHigh: Color(0xFF414559), // surface0 — "Surface Elements"
  onSurface: Color(0xFFC6D0F5), // text — "Body Copy"
  onSurfaceVariant: Color(0xFFA5ADCE), // subtext0 — "Sub-Headlines, Labels"
  outline: Color(0xFF737994), // overlay0 — "Inactive Border"
  outlineVariant: Color(0xFF51576D), // surface1
  error: Color(0xFFE78284), // red — "Errors"
  onError: Color(0xFF303446), // base
  errorContainer: Color(0xFF5E4856), // red 25% over base
  onErrorContainer: Color(0xFFC6D0F5), // text
  inverseSurface: Color(0xFFC6D0F5), // text
  onInverseSurface: Color(0xFF303446), // base
);

/// Catppuccin Macchiato.
const _catppuccinMacchiato = _PaletteTokens(
  primary: Color(0xFFC6A0F6), // mauve
  onPrimary: Color(0xFF24273A), // base — "On Accent"
  primaryContainer: Color(0xFF494D64), // surface1
  onPrimaryContainer: Color(0xFFCAD3F5), // text
  secondaryContainer: Color(0xFF363A4F), // surface0
  onSecondaryContainer: Color(0xFFCAD3F5), // text
  tertiary: Color(0xFFF5BDE6), // pink
  tertiaryContainer: Color(0xFF584C65), // pink 25% over base
  onTertiaryContainer: Color(0xFFCAD3F5), // text
  surface: Color(0xFF24273A), // base — "Background Pane"
  surfaceContainerLow: Color(0xFF1E2030), // mantle — "Secondary Panes"
  surfaceContainer: Color(0xFF181926), // crust — "Secondary Panes"
  surfaceContainerHigh: Color(0xFF363A4F), // surface0 — "Surface Elements"
  onSurface: Color(0xFFCAD3F5), // text — "Body Copy"
  onSurfaceVariant: Color(0xFFA5ADCB), // subtext0 — "Sub-Headlines, Labels"
  outline: Color(0xFF6E738D), // overlay0 — "Inactive Border"
  outlineVariant: Color(0xFF494D64), // surface1
  error: Color(0xFFED8796), // red — "Errors"
  onError: Color(0xFF24273A), // base
  errorContainer: Color(0xFF563F51), // red 25% over base
  onErrorContainer: Color(0xFFCAD3F5), // text
  inverseSurface: Color(0xFFCAD3F5), // text
  onInverseSurface: Color(0xFF24273A), // base
);

/// Catppuccin Mocha.
const _catppuccinMocha = _PaletteTokens(
  primary: Color(0xFFCBA6F7), // mauve
  onPrimary: Color(0xFF1E1E2E), // base — "On Accent"
  primaryContainer: Color(0xFF45475A), // surface1
  onPrimaryContainer: Color(0xFFCDD6F4), // text
  secondaryContainer: Color(0xFF313244), // surface0
  onSecondaryContainer: Color(0xFFCDD6F4), // text
  tertiary: Color(0xFFF5C2E7), // pink
  tertiaryContainer: Color(0xFF54475C), // pink 25% over base
  onTertiaryContainer: Color(0xFFCDD6F4), // text
  surface: Color(0xFF1E1E2E), // base — "Background Pane"
  surfaceContainerLow: Color(0xFF181825), // mantle — "Secondary Panes"
  surfaceContainer: Color(0xFF11111B), // crust — "Secondary Panes"
  surfaceContainerHigh: Color(0xFF313244), // surface0 — "Surface Elements"
  onSurface: Color(0xFFCDD6F4), // text — "Body Copy"
  onSurfaceVariant: Color(0xFFA6ADC8), // subtext0 — "Sub-Headlines, Labels"
  outline: Color(0xFF6C7086), // overlay0 — "Inactive Border"
  outlineVariant: Color(0xFF45475A), // surface1
  error: Color(0xFFF38BA8), // red — "Errors"
  onError: Color(0xFF1E1E2E), // base
  errorContainer: Color(0xFF53394C), // red 25% over base
  onErrorContainer: Color(0xFFCDD6F4), // text
  inverseSurface: Color(0xFFCDD6F4), // text
  onInverseSurface: Color(0xFF1E1E2E), // base
);

/// Solarized light.
const _solarizedLight = _PaletteTokens(
  primary: Color(0xFF268BD2), // blue
  onPrimary: Color(0xFFFDF6E3), // base3
  primaryContainer: Color(0xFFD2E1E0), // blue 20% over background
  onPrimaryContainer: Color(0xFF586E75), // emphasized content
  secondaryContainer: Color(0xFFD7D6C8), // background highlight toward secondary
  onSecondaryContainer: Color(0xFF586E75), // emphasized content
  tertiary: Color(0xFFD33682), // magenta
  tertiaryContainer: Color(0xFFF5D0D0), // magenta 20% over background
  onTertiaryContainer: Color(0xFF586E75), // emphasized content
  surface: Color(0xFFFDF6E3), // background
  surfaceContainerLow: Color(0xFFEEE8D5), // background highlights
  surfaceContainer: Color(0xFFE0DDCD), // highlights, a step darker
  surfaceContainerHigh: Color(0xFFD3D3C5), // highlights toward secondary
  onSurface: Color(0xFF586E75), // emphasized content (see note)
  onSurfaceVariant: Color(0xFF657B83), // body text (see note)
  outline: Color(0xFF93A1A1), // secondary content
  outlineVariant: Color(0xFFEEE8D5), // background highlights
  error: Color(0xFFDC322F), // red
  onError: Color(0xFFFDF6E3), // base3
  errorContainer: Color(0xFFF6CFBF), // red 20% over background
  onErrorContainer: Color(0xFF586E75), // emphasized content
  inverseSurface: Color(0xFF002B36), // opposite background
  onInverseSurface: Color(0xFF93A1A1), // its body text
);

/// Solarized dark.
const _solarizedDark = _PaletteTokens(
  primary: Color(0xFF268BD2), // blue
  onPrimary: Color(0xFFFDF6E3), // base3
  primaryContainer: Color(0xFF083E55), // blue 20% over background
  onPrimaryContainer: Color(0xFF93A1A1), // emphasized content
  secondaryContainer: Color(0xFF1B444F), // background highlight toward secondary
  onSecondaryContainer: Color(0xFF93A1A1), // emphasized content
  tertiary: Color(0xFFD33682), // magenta
  tertiaryContainer: Color(0xFF2A2D45), // magenta 20% over background
  onTertiaryContainer: Color(0xFF93A1A1), // emphasized content
  surface: Color(0xFF002B36), // background
  surfaceContainerLow: Color(0xFF073642), // background highlights
  surfaceContainer: Color(0xFF04303C), // between background and highlights
  surfaceContainerHigh: Color(0xFF1B444F), // highlights toward secondary
  onSurface: Color(0xFF93A1A1), // emphasized content (see note)
  onSurfaceVariant: Color(0xFF839496), // body text (see note)
  outline: Color(0xFF586E75), // secondary content
  outlineVariant: Color(0xFF073642), // background highlights
  error: Color(0xFFDC322F), // red
  onError: Color(0xFFFDF6E3), // base3
  errorContainer: Color(0xFF2C2C35), // red 20% over background
  onErrorContainer: Color(0xFF93A1A1), // emphasized content
  inverseSurface: Color(0xFFFDF6E3), // opposite background
  onInverseSurface: Color(0xFF657B83), // its body text
);

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

/// Brightness of palettes that exist in one variant only, `null` for those with both. Most are
/// dark-only (Dracula, Nord, Gruvbox, three Catppuccin flavours); Catppuccin Latte is its
/// light-only counterpart. [buildTheme] ignores the requested brightness for them: `MikroApp`
/// always builds both `theme` and `darkTheme`, so the other slot has to hold something, and the
/// palette's one variant is the only answer its source supports. Inventing the missing variant
/// would put colours on screen that the source never specifies.
Brightness? _fixedBrightness(AppPalette palette) => switch (palette) {
      AppPalette.md3 || AppPalette.solarized => null,
      AppPalette.catppuccinLatte => Brightness.light,
      AppPalette.dracula ||
      AppPalette.nord ||
      AppPalette.gruvbox ||
      AppPalette.catppuccinFrappe ||
      AppPalette.catppuccinMacchiato ||
      AppPalette.catppuccinMocha =>
        Brightness.dark,
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
// Accent, second accent, background — the same pattern as Dracula's card.
const _latteSwatch = [Color(0xFF8839EF), Color(0xFFEA76CB), Color(0xFFEFF1F5)];
const _frappeSwatch = [Color(0xFFCA9EE6), Color(0xFFF4B8E4), Color(0xFF303446)];
const _macchiatoSwatch = [Color(0xFFC6A0F6), Color(0xFFF5BDE6), Color(0xFF24273A)];
const _mochaSwatch = [Color(0xFFCBA6F7), Color(0xFFF5C2E7), Color(0xFF1E1E2E)];
const _solarizedLightSwatch = [Color(0xFF268BD2), Color(0xFFD33682), Color(0xFFFDF6E3)];
const _solarizedDarkSwatch = [Color(0xFF268BD2), Color(0xFFD33682), Color(0xFF002B36)];

/// The three preview colours for [palette]'s card in the settings screen.
List<Color> paletteSwatch(AppPalette palette, Brightness brightness) => switch (palette) {
      AppPalette.md3 =>
        brightness == Brightness.light ? _md3LightSwatch : _md3DarkSwatch,
      AppPalette.dracula => _draculaSwatch,
      AppPalette.nord => _nordSwatch,
      AppPalette.gruvbox => _gruvboxSwatch,
      AppPalette.catppuccinLatte => _latteSwatch,
      AppPalette.catppuccinFrappe => _frappeSwatch,
      AppPalette.catppuccinMacchiato => _macchiatoSwatch,
      AppPalette.catppuccinMocha => _mochaSwatch,
      AppPalette.solarized =>
        brightness == Brightness.light ? _solarizedLightSwatch : _solarizedDarkSwatch,
    };

_PaletteTokens _tokensFor(AppPalette palette, Brightness brightness) =>
    switch ((palette, brightness)) {
      (AppPalette.md3, Brightness.light) => _md3Light,
      (AppPalette.md3, Brightness.dark) => _md3Dark,
      (AppPalette.solarized, Brightness.light) => _solarizedLight,
      (AppPalette.solarized, Brightness.dark) => _solarizedDark,
      // Brightness is irrelevant here — these palettes have one variant, see [_fixedBrightness].
      (AppPalette.dracula, _) => _dracula,
      (AppPalette.nord, _) => _nord,
      (AppPalette.gruvbox, _) => _gruvbox,
      (AppPalette.catppuccinLatte, _) => _catppuccinLatte,
      (AppPalette.catppuccinFrappe, _) => _catppuccinFrappe,
      (AppPalette.catppuccinMacchiato, _) => _catppuccinMacchiato,
      (AppPalette.catppuccinMocha, _) => _catppuccinMocha,
    };

Color _seedFor(AppPalette palette) => switch (palette) {
      AppPalette.md3 => _md3Seed,
      AppPalette.dracula => _draculaSeed,
      AppPalette.nord => _nordSeed,
      AppPalette.gruvbox => _gruvboxSeed,
      // Mauve, each flavour's own shade.
      AppPalette.catppuccinLatte => const Color(0xFF8839EF),
      AppPalette.catppuccinFrappe => const Color(0xFFCA9EE6),
      AppPalette.catppuccinMacchiato => const Color(0xFFC6A0F6),
      AppPalette.catppuccinMocha => const Color(0xFFCBA6F7),
      AppPalette.solarized => const Color(0xFF268BD2),
    };

/// Builds the Material 3 theme for [palette] in [brightness].
///
/// Every role the design names is applied verbatim. Roles it stays silent about (secondary,
/// onTertiary, scrim, shadow…) come from `ColorScheme.fromSeed`, so the scheme is complete and
/// internally consistent instead of being padded with guesses.
ThemeData buildTheme({required AppPalette palette, required Brightness brightness}) {
  // Single-variant palettes pin the brightness, so their scheme stays internally consistent: the
  // roles the source does not name are generated against the same brightness as the ones it does.
  final effective = _fixedBrightness(palette) ?? brightness;
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

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [AccentPalette.forTheme(palette, effective)],
  );
}
