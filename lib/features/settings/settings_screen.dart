import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/provider_config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_providers.dart';
import '../../l10n/app_localizations.dart';

/// Single theme choice card in the grid. The mockup displays six cards in a 2x3 layout
/// and couples mode with palette — each card represents a (mode, palette) pair.
@immutable
class _ThemeChoice {
  const _ThemeChoice({
    required this.label,
    required this.mode,
    required this.palette,
    this.icon,
  });

  final String label;
  final ThemeMode mode;
  final AppPalette palette;

  /// "System" card displays an icon instead of preview dots — palette depends on the system setting,
  /// so a fixed color triplet cannot be shown.
  final IconData? icon;

  /// Brightness used for rendering the palette preview on the card.
  Brightness get previewBrightness =>
      mode == ThemeMode.light ? Brightness.light : Brightness.dark;
}

/// Dracula, Nord, and Gruvbox are proper names — they remain identical across languages and do not
/// need ARB entries. Only the other three labels are localized, so the list is built
/// at build time rather than declared as a constant.
List<_ThemeChoice> _themeChoices(AppLocalizations l10n) => [
      _ThemeChoice(
          label: l10n.settingsThemeLight, mode: ThemeMode.light, palette: AppPalette.md3),
      _ThemeChoice(label: l10n.settingsThemeDark, mode: ThemeMode.dark, palette: AppPalette.md3),
      _ThemeChoice(label: 'Dracula', mode: ThemeMode.dark, palette: AppPalette.dracula),
      _ThemeChoice(label: 'Nord', mode: ThemeMode.dark, palette: AppPalette.nord),
      _ThemeChoice(label: 'Gruvbox', mode: ThemeMode.dark, palette: AppPalette.gruvbox),
      _ThemeChoice(
        label: l10n.settingsThemeSystem,
        mode: ThemeMode.system,
        palette: AppPalette.md3,
        icon: Symbols.brightness_auto_rounded,
      ),
    ];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _sttModel = TextEditingController();
  final _tagModel = TextEditingController();
  ProviderPreset _preset = ProviderPreset.groq;
  var _loaded = false;
  var _apiKeyHidden = true;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).load().then((config) {
      if (!mounted) return;
      if (config != null) {
        _baseUrl.text = config.baseUrl;
        _apiKey.text = config.apiKey;
        _sttModel.text = config.sttModel;
        _tagModel.text = config.tagModel;
        _preset = ProviderPreset.values.firstWhere(
          (p) => p.baseUrl == config.baseUrl,
          orElse: () => ProviderPreset.custom,
        );
      } else {
        _applyPreset(ProviderPreset.groq);
      }
      setState(() => _loaded = true);
    });
  }

  void _applyPreset(ProviderPreset preset) {
    _preset = preset;
    if (preset != ProviderPreset.custom) {
      _baseUrl.text = preset.baseUrl;
      _sttModel.text = preset.sttModel;
      _tagModel.text = preset.tagModel;
    }
    setState(() {});
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).save(ProviderConfig(
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.trim(),
          sttModel: _sttModel.text.trim(),
          tagModel: _tagModel.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
    }
  }

  Future<void> _applyThemeChoice(_ThemeChoice choice) async {
    await ref.read(themeModeProvider.notifier).setMode(choice.mode);
    await ref.read(themePaletteProvider.notifier).setPalette(choice.palette);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _sttModel.dispose();
    _tagModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                l10n.settingsTitle,
                style: TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: colors.onSurface,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _providerSection(colors, l10n),
                            const SizedBox(height: 20),
                            _themeSection(colors, l10n),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerSection(ColorScheme colors, AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(l10n.settingsProviderSection, colors),
          const SizedBox(height: 10),
          _providerConnectedButtonGroup(colors, l10n),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrl,
            enabled: _preset == ProviderPreset.custom,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration(l10n.settingsBaseUrl, colors),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKey,
            obscureText: _apiKeyHidden,
            style: TextStyle(fontSize: 15, letterSpacing: 2, color: colors.onSurface),
            decoration: _fieldDecoration(
              l10n.settingsApiKey,
              colors,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _apiKeyHidden = !_apiKeyHidden),
                icon: Icon(
                  _apiKeyHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                  fill: 1,
                  size: 22,
                ),
                color: colors.onSurfaceVariant,
                tooltip: _apiKeyHidden ? l10n.settingsShowKey : l10n.settingsHideKey,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sttModel,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration(l10n.settingsSttModel, colors),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tagModel,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration(l10n.settingsTagModel, colors),
          ),
        ],
      );

  /// Provider segment button group in MD3 Expressive connected style:
  /// height 56 dp, 2 dp gap, outer radii 28 dp, inner radii 8 dp,
  /// with selected segment receiving full 28 dp rounding on all corners.
  Widget _providerConnectedButtonGroup(ColorScheme colors, AppLocalizations l10n) {
    final segments = [
      (preset: ProviderPreset.groq, label: 'Groq'),
      (preset: ProviderPreset.openai, label: 'OpenAI'),
      (preset: ProviderPreset.custom, label: l10n.settingsProviderCustom),
    ];

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _providerSegmentItem(
                preset: segments[i].preset,
                label: segments[i].label,
                index: i,
                total: segments.length,
                isSelected: _preset == segments[i].preset,
                colors: colors,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _providerSegmentItem({
    required ProviderPreset preset,
    required String label,
    required int index,
    required int total,
    required bool isSelected,
    required ColorScheme colors,
  }) {
    final BorderRadius radius;
    if (isSelected) {
      radius = BorderRadius.circular(28);
    } else if (index == 0) {
      radius = const BorderRadius.horizontal(
        left: Radius.circular(28),
        right: Radius.circular(8),
      );
    } else if (index == total - 1) {
      radius = const BorderRadius.horizontal(
        left: Radius.circular(8),
        right: Radius.circular(28),
      );
    } else {
      radius = BorderRadius.circular(8);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      decoration: BoxDecoration(
        color: isSelected ? colors.primary : colors.surfaceContainerHigh,
        borderRadius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _applyPreset(preset),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeSection(ColorScheme colors, AppLocalizations l10n) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(themePaletteProvider);
    final choices = _themeChoices(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(l10n.settingsThemeSection, colors),
        const SizedBox(height: 10),
        for (var row = 0; row < choices.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (final choice in choices.skip(row).take(3)) ...[
                if (choice != choices[row]) const SizedBox(width: 10),
                Expanded(
                  child: _themeCard(
                    choice,
                    colors,
                    selected: choice.mode == mode && choice.palette == palette,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _themeCard(_ThemeChoice choice, ColorScheme colors, {required bool selected}) =>
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _applyThemeChoice(choice),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? colors.surfaceContainerLow : null,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choice.icon case final icon?)
                Icon(icon, fill: 1, size: 16, color: colors.onSurfaceVariant)
              else
                _swatchDots(choice, colors),
              const SizedBox(height: 8),
              Text(
                choice.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _swatchDots(_ThemeChoice choice, ColorScheme colors) {
    final swatch = paletteSwatch(choice.palette, choice.previewBrightness);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, color) in swatch.indexed) ...[
          if (index > 0) const SizedBox(width: 4),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              // Surface dot on light palette is near-white — without an outline it would blend
              // into the light card background. The mockup renders an outline only there.
              border: index == swatch.length - 1 &&
                      choice.previewBrightness == Brightness.light
                  ? Border.all(color: colors.outlineVariant)
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _saveButton() => SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Symbols.save_rounded, fill: 1, size: 20),
          label: Text(AppLocalizations.of(context).settingsSave),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );

  /// Section header. Small-caps casing comes from ARB rather than `toUpperCase()` —
  /// typography casing rules are language-dependent.
  Widget _sectionLabel(String text, ColorScheme colors) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colors.primary,
          ),
        ),
      );

  /// Technical values (URL, model names) are rendered in Roboto Mono. Font family comes from
  /// [monoFontFamily] constant matching the bundled asset.
  TextStyle _monoValueStyle(ColorScheme colors) => TextStyle(
        fontSize: 15,
        fontFamily: monoFontFamily,
        fontFamilyFallback: monoFontFallback,
        color: colors.onSurface,
      );

  InputDecoration _fieldDecoration(String label, ColorScheme colors, {Widget? suffixIcon}) {
    const shape = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(4),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colors.surfaceContainer,
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      floatingLabelStyle: TextStyle(fontSize: 12, color: colors.primary),
      enabledBorder: UnderlineInputBorder(
        borderRadius: shape,
        borderSide: BorderSide(color: colors.onSurfaceVariant),
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: shape,
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      disabledBorder: UnderlineInputBorder(
        borderRadius: shape,
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      border: const UnderlineInputBorder(borderRadius: shape),
    );
  }
}
