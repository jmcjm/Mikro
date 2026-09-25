import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/theme/accent_palette.dart';
import 'package:mikro/core/theme/app_theme.dart';

void main() {
  test('every theme carries eight accent colours in the same hue order', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final accents = buildTheme(palette: palette, brightness: brightness)
            .extension<AccentPalette>();
        expect(accents, isNotNull, reason: '$palette $brightness');
        expect(accents!.marks, hasLength(AccentPalette.count), reason: '$palette $brightness');
      }
    }
  });

  test('colours follow the theme: index 0 is each palette\'s own red', () {
    Color red(AppPalette p, Brightness b) =>
        buildTheme(palette: p, brightness: b).extension<AccentPalette>()!.mark(0)!;
    expect(red(AppPalette.dracula, Brightness.dark), const Color(0xFFFF5555));
    expect(red(AppPalette.nord, Brightness.dark), const Color(0xFFBF616A));
    expect(red(AppPalette.gruvbox, Brightness.dark), const Color(0xFFFB4934));
    expect(red(AppPalette.md3, Brightness.light), isNot(red(AppPalette.md3, Brightness.dark)),
        reason: 'baseline has separate light and dark shades');
  });

  test('no colour or an unknown index means the default look', () {
    const palette = AccentPalette([Colors.red]);
    expect(palette.mark(null), isNull);
    expect(palette.mark(5), isNull);
    expect(palette.chip(null, Brightness.dark), isNull);
  });
}
