import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Colours a user can give a tag or a note, following the active theme: each [AppPalette]
/// supplies its own shade of the same eight hues, so "red" is Dracula's red under Dracula and
/// Nord's under Nord. Registered as a [ThemeExtension] by [buildTheme]; read with [of].
///
/// The database stores the INDEX, so the hue order is fixed — entries may only ever be
/// appended, in every palette, or existing tags and notes would change colour.
@immutable
class AccentPalette extends ThemeExtension<AccentPalette> {
  const AccentPalette(this.marks);

  /// Red, orange, yellow, green, teal, blue, purple, pink — in this palette's shades.
  final List<Color> marks;

  static const count = 8;

  // Material 600 tones read well on light surfaces; on dark ones they sink, so the dark
  // variant uses the 300 tones of the same hues.
  static const _md3Light = AccentPalette([
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047),
    Color(0xFF00897B), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFD81B60),
  ]);
  static const _md3Dark = AccentPalette([
    Color(0xFFE57373), Color(0xFFFFB74D), Color(0xFFFFF176), Color(0xFF81C784),
    Color(0xFF4DB6AC), Color(0xFF64B5F6), Color(0xFFBA68C8), Color(0xFFF06292),
  ]);
  // Dracula spec colours. It has no blue of its own; "comment" (#6272A4) is its blue-grey.
  static const _dracula = AccentPalette([
    Color(0xFFFF5555), Color(0xFFFFB86C), Color(0xFFF1FA8C), Color(0xFF50FA7B),
    Color(0xFF8BE9FD), Color(0xFF6272A4), Color(0xFFBD93F9), Color(0xFFFF79C6),
  ]);
  // Nord Aurora and Frost. Nord has a single purple, so pink is a lighter tint of it.
  static const _nord = AccentPalette([
    Color(0xFFBF616A), Color(0xFFD08770), Color(0xFFEBCB8B), Color(0xFFA3BE8C),
    Color(0xFF8FBCBB), Color(0xFF81A1C1), Color(0xFFB48EAD), Color(0xFFD7A9C9),
  ]);
  // Gruvbox dark, bright variants; its neutral purple for purple, bright purple for pink.
  static const _gruvbox = AccentPalette([
    Color(0xFFFB4934), Color(0xFFFE8019), Color(0xFFFABD2F), Color(0xFFB8BB26),
    Color(0xFF8EC07C), Color(0xFF83A598), Color(0xFFB16286), Color(0xFFD3869B),
  ]);

  static AccentPalette forTheme(AppPalette palette, Brightness brightness) =>
      switch (palette) {
        AppPalette.md3 => brightness == Brightness.light ? _md3Light : _md3Dark,
        AppPalette.dracula => _dracula,
        AppPalette.nord => _nord,
        AppPalette.gruvbox => _gruvbox,
      };

  /// Palette of the surrounding theme; the light baseline when a theme without the extension
  /// is in use (tests pumping a bare MaterialApp).
  static AccentPalette of(BuildContext context) =>
      Theme.of(context).extension<AccentPalette>() ?? _md3Light;

  /// The colour itself, for small marks (a dot, an outline) and swatches; `null` for no
  /// colour or an index this version does not know (a newer version's colour after a
  /// downgrade) — the default look.
  Color? mark(int? index) =>
      index == null || index < 0 || index >= marks.length ? null : marks[index];

  /// Small round marker in colour [index]; nothing for no colour.
  Widget dot(int? index, {double size = 10}) {
    final color = mark(index);
    if (color == null) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  static final _chipCache = <(Color, Brightness), (Color, Color)>{};

  /// Background and foreground of a tag chip in colour [index]. A tonal pair derived from the
  /// mark through [ColorScheme.fromSeed] (fidelity variant, so it stays close to the hue),
  /// which keeps text contrast right on light and dark surfaces alike.
  (Color background, Color foreground)? chip(int? index, Brightness brightness) {
    final seed = mark(index);
    if (seed == null) return null;
    return _chipCache.putIfAbsent((seed, brightness), () {
      final scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      return (scheme.primaryContainer, scheme.onPrimaryContainer);
    });
  }

  @override
  AccentPalette copyWith({List<Color>? marks}) => AccentPalette(marks ?? this.marks);

  @override
  AccentPalette lerp(AccentPalette? other, double t) {
    if (other == null) return this;
    return AccentPalette([
      for (var i = 0; i < marks.length; i++) Color.lerp(marks[i], other.marks[i], t)!,
    ]);
  }
}
