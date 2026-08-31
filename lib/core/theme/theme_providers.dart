import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_theme.dart';

/// Preference keys. These are the on-disk format and survive app upgrades — renaming one
/// silently resets the user's theme, so they are pinned by tests.
const themeModeKey = 'theme_mode';
const themePaletteKey = 'theme_palette';

/// Selected light/dark mode, persisted across restarts. Defaults to following the system.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Untyped read: getString() throws on values of different types (e.g. version downgrade or key collision),
    // and an exception in the first frame results in a fatal white screen.
    // An unknown value should simply fall back to the default — matching onboarding_providers.dart.
    final stored = ref.read(sharedPrefsProvider).get(themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(themeModeKey, mode.name);
  }
}

/// Selected colour palette, persisted across restarts. Defaults to the MD3 baseline.
class ThemePaletteController extends Notifier<AppPalette> {
  @override
  AppPalette build() {
    // Just like with mode: a typed read would throw on first frame, and palette has a default fallback.
    final stored = ref.read(sharedPrefsProvider).get(themePaletteKey);
    return AppPalette.values.firstWhere(
      (palette) => palette.name == stored,
      orElse: () => AppPalette.md3,
    );
  }

  Future<void> setPalette(AppPalette palette) async {
    state = palette;
    await ref.read(sharedPrefsProvider).setString(themePaletteKey, palette.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

final themePaletteProvider =
    NotifierProvider<ThemePaletteController, AppPalette>(ThemePaletteController.new);
