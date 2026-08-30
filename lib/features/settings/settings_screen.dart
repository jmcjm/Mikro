import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/provider_config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_providers.dart';

/// Jedna karta w siatce wyboru motywu. Makieta pokazuje szesc kart w ukladzie 2x3 i nie
/// rozdziela trybu od palety — kazda karta to gotowa para (tryb, paleta), stad oba pola.
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

  /// Karta „Systemowy" zamiast kropek podgladu ma ikone — paleta zalezy wtedy od systemu,
  /// wiec nie da sie pokazac jednej trojki kolorow.
  final IconData? icon;

  /// Jasnosc, w ktorej pokazujemy podglad palety na karcie.
  Brightness get previewBrightness =>
      mode == ThemeMode.light ? Brightness.light : Brightness.dark;
}

const _themeChoices = [
  _ThemeChoice(label: 'Jasny', mode: ThemeMode.light, palette: AppPalette.md3),
  _ThemeChoice(label: 'Ciemny', mode: ThemeMode.dark, palette: AppPalette.md3),
  _ThemeChoice(label: 'Dracula', mode: ThemeMode.dark, palette: AppPalette.dracula),
  _ThemeChoice(label: 'Nord', mode: ThemeMode.dark, palette: AppPalette.nord),
  _ThemeChoice(label: 'Gruvbox', mode: ThemeMode.dark, palette: AppPalette.gruvbox),
  _ThemeChoice(
    label: 'Systemowy',
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ustawienia zapisane.')));
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

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Ustawienia',
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
                            _providerSection(colors),
                            const SizedBox(height: 20),
                            _themeSection(colors),
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

  Widget _providerSection(ColorScheme colors) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Provider', colors),
          const SizedBox(height: 10),
          SegmentedButton<ProviderPreset>(
            segments: const [
              ButtonSegment(value: ProviderPreset.groq, label: Text('Groq')),
              ButtonSegment(value: ProviderPreset.openai, label: Text('OpenAI')),
              ButtonSegment(value: ProviderPreset.custom, label: Text('Własny')),
            ],
            selected: {_preset},
            onSelectionChanged: (selection) => _applyPreset(selection.first),
            selectedIcon: const Icon(Symbols.check_rounded, fill: 1, size: 18),
            style: SegmentedButton.styleFrom(
              side: BorderSide(color: colors.outline),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              foregroundColor: colors.onSurface,
              selectedForegroundColor: colors.onSecondaryContainer,
              selectedBackgroundColor: colors.secondaryContainer,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              minimumSize: const Size(0, 44),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrl,
            enabled: _preset == ProviderPreset.custom,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration('Base URL', colors),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKey,
            obscureText: _apiKeyHidden,
            style: TextStyle(fontSize: 15, letterSpacing: 2, color: colors.onSurface),
            decoration: _fieldDecoration(
              'Klucz API',
              colors,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _apiKeyHidden = !_apiKeyHidden),
                icon: Icon(
                  _apiKeyHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                  fill: 1,
                  size: 22,
                ),
                color: colors.onSurfaceVariant,
                tooltip: _apiKeyHidden ? 'Pokaż klucz' : 'Ukryj klucz',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Icon(Symbols.lock_rounded,
                    fill: 1, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trzymany w keystore systemu, nie w SharedPreferences',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sttModel,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration('Model STT', colors),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tagModel,
            style: _monoValueStyle(colors),
            decoration: _fieldDecoration('Model tagowania', colors),
          ),
        ],
      );

  Widget _themeSection(ColorScheme colors) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(themePaletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Motyw', colors),
        const SizedBox(height: 10),
        for (var row = 0; row < _themeChoices.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (final choice in _themeChoices.skip(row).take(3)) ...[
                if (choice != _themeChoices[row]) const SizedBox(width: 10),
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
              // Kropka powierzchni jasnej palety jest prawie biala — bez obwodki znikneloby
              // ja na jasnej karcie. Makieta rysuje ja tylko tam.
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
          label: const Text('Zapisz'),
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

  Widget _sectionLabel(String text, ColorScheme colors) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colors.primary,
          ),
        ),
      );

  /// Wartosci techniczne (URL, nazwy modeli) design sklada krojem Roboto Mono. Fontu nie
  /// bundlujemy, wiec podajemy zapas na systemowy monospace zamiast cicho wracac do proporcjonalnego.
  TextStyle _monoValueStyle(ColorScheme colors) => TextStyle(
        fontSize: 15,
        fontFamily: 'Roboto Mono',
        fontFamilyFallback: const ['monospace'],
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
