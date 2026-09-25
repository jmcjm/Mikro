import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/provider_config.dart';
import '../../core/providers.dart';
import '../../core/settings/settings_repository.dart';
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

/// Editable settings of one [ApiTask]: preset, address, key and model.
class _TaskForm {
  _TaskForm(this.task);

  final ApiTask task;
  final baseUrl = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController();
  final temperature = TextEditingController();
  final topP = TextEditingController();
  ProviderPreset preset = ProviderPreset.groq;
  bool keyHidden = true;
  bool samplingEnabled = false;

  /// Transcription does not go through chat completions, so only titles/tags and notes
  /// offer sampling control.
  bool get hasSampling => task != ApiTask.stt;

  void load(ServiceConfig config, SamplingParams samplingValues) {
    baseUrl.text = config.baseUrl;
    apiKey.text = config.apiKey;
    model.text = config.model;
    preset = ProviderPreset.of(config.baseUrl);
    loadSampling(enabled: config.sampling != null, values: samplingValues);
  }

  void loadSampling({required bool enabled, required SamplingParams values}) {
    samplingEnabled = enabled;
    temperature.text = _formatNumber(values.temperature);
    topP.text = _formatNumber(values.topP);
  }

  static String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Accepts a decimal comma as well; anything unparsable falls back to the task default
  /// rather than blocking the save. Clamped to the range the OpenAI API accepts.
  static double _parse(String text, double fallback, double max) =>
      (double.tryParse(text.trim().replaceAll(',', '.')) ?? fallback).clamp(0, max).toDouble();

  SamplingParams? get _samplingValue {
    if (!hasSampling || !samplingEnabled) return null;
    final defaults = SamplingParams.defaultFor(task);
    return SamplingParams(
      temperature: _parse(temperature.text, defaults.temperature, 2),
      topP: _parse(topP.text, defaults.topP, 1),
    );
  }

  /// Switching preset fills address and model; the key is left alone — it belongs to the
  /// user, and clearing it on a misclick would be worse than a stale value.
  void applyPreset(ProviderPreset next) {
    preset = next;
    if (next == ProviderPreset.custom) return;
    baseUrl.text = next.baseUrl;
    model.text = next.model(task);
  }

  ServiceConfig get value => ServiceConfig(
        baseUrl: baseUrl.text.trim(),
        apiKey: apiKey.text.trim(),
        model: model.text.trim(),
        sampling: _samplingValue,
      );

  void dispose() {
    temperature.dispose();
    topP.dispose();
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _forms = {for (final task in ApiTask.values) task: _TaskForm(task)};
  var _noteStyle = NoteStyle.detailed;
  final _noteStyleCustom = TextEditingController();
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    for (final form in _forms.values) {
      final config = await repo.raw(form.task);
      // Nothing stored at all (fresh install) -> start from the Groq preset, as before.
      if (config.baseUrl.isEmpty) {
        form.applyPreset(ProviderPreset.groq);
        form.loadSampling(enabled: false, values: repo.samplingValues(form.task));
      } else {
        form.load(config, repo.samplingValues(form.task));
      }
    }
    final style = repo.loadNoteStyle();
    _noteStyle = style.style;
    _noteStyleCustom.text = style.custom;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    // Taken before the awaits: this screen may be popped mid-save, and the others still
    // need to hear about it.
    final revision = ref.read(settingsRevisionProvider.notifier);
    for (final form in _forms.values) {
      await repo.save(form.task, form.value);
    }
    await repo.saveNoteStyle(
        NoteStyleSetting(style: _noteStyle, custom: _noteStyleCustom.text.trim()));
    revision.state++;
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
    for (final form in _forms.values) {
      form.dispose();
    }
    _noteStyleCustom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsRevisionProvider, (_, _) => _load());
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(canPop ? 8 : 20, 16, 20, 12),
              child: Row(
                children: [
                  if (canPop) ...[
                    IconButton(
                      icon: Icon(Symbols.arrow_back_rounded, color: colors.onSurface),
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    l10n.settingsTitle,
                    style: TextStyle(
                      fontSize: 32,
                      height: 40 / 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colors.onSurface,
                    ),
                  ),
                ],
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
                            for (final task in ApiTask.values) ...[
                              _taskSection(_forms[task]!, colors, l10n),
                              const SizedBox(height: 24),
                            ],
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

  Widget _taskSection(_TaskForm form, ColorScheme colors, AppLocalizations l10n) {
    final (title, modelHelp, keyHelp) = switch (form.task) {
      ApiTask.stt => (l10n.settingsSttSection, l10n.settingsSttModelHelp, null),
      ApiTask.tags => (l10n.settingsTagsSection, null, l10n.settingsApiKeyInheritHelp),
      ApiTask.notes => (l10n.settingsNotesSection, null, l10n.settingsApiKeyInheritHelp),
      ApiTask.translate =>
        (l10n.settingsTranslateSection, null, l10n.settingsApiKeyInheritHelp),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(title, colors),
        const SizedBox(height: 10),
        _providerConnectedButtonGroup(form, colors, l10n),
        const SizedBox(height: 10),
        TextField(
          controller: form.baseUrl,
          enabled: form.preset == ProviderPreset.custom,
          style: _monoValueStyle(colors),
          decoration: _fieldDecoration(l10n.settingsBaseUrl, colors),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: form.apiKey,
          obscureText: form.keyHidden,
          style: TextStyle(fontSize: 15, letterSpacing: 2, color: colors.onSurface),
          decoration: _fieldDecoration(
            l10n.settingsApiKey,
            colors,
            suffixIcon: IconButton(
              onPressed: () => setState(() => form.keyHidden = !form.keyHidden),
              icon: Icon(
                form.keyHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                fill: 1,
                size: 22,
              ),
              color: colors.onSurfaceVariant,
              tooltip: form.keyHidden ? l10n.settingsShowKey : l10n.settingsHideKey,
            ),
          ).copyWith(helperText: keyHelp, helperMaxLines: 3),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: form.model,
          style: _monoValueStyle(colors),
          decoration: _fieldDecoration(l10n.settingsModel, colors)
              .copyWith(helperText: modelHelp, helperMaxLines: 3),
        ),
        if (form.hasSampling) ...[
          const SizedBox(height: 6),
          _samplingControl(form, colors, l10n),
        ],
        if (form.task == ApiTask.notes) ...[
          const SizedBox(height: 16),
          _noteStylePicker(colors, l10n),
        ],
      ],
    );
  }

  /// Opt-in temperature and top_p. Off by default because some models (OpenAI's reasoning
  /// family) reject any non-default value with HTTP 400; off means neither is sent.
  Widget _samplingControl(_TaskForm form, ColorScheme colors, AppLocalizations l10n) {
    final numberKeyboard = const TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: form.samplingEnabled,
          onChanged: (on) => setState(() => form.samplingEnabled = on),
          title: Text(
            l10n.settingsSampling,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
          subtitle: Text(
            l10n.settingsSamplingHelp,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ),
        if (form.samplingEnabled) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.temperature,
                  keyboardType: numberKeyboard,
                  style: _monoValueStyle(colors),
                  decoration: _fieldDecoration(l10n.settingsTemperature, colors)
                      .copyWith(helperText: '0–2'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: form.topP,
                  keyboardType: numberKeyboard,
                  style: _monoValueStyle(colors),
                  decoration:
                      _fieldDecoration('top_p', colors).copyWith(helperText: '0–1'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Note style: three presets and "custom", whose text goes to the model as instructions.
  /// The custom text stays stored while a preset is selected, so trying a preset costs nothing.
  Widget _noteStylePicker(ColorScheme colors, AppLocalizations l10n) {
    final options = [
      (NoteStyle.detailed, l10n.settingsNoteStyleDetailed, l10n.settingsNoteStyleDetailedHelp),
      (NoteStyle.concise, l10n.settingsNoteStyleConcise, l10n.settingsNoteStyleConciseHelp),
      (NoteStyle.meeting, l10n.settingsNoteStyleMeeting, l10n.settingsNoteStyleMeetingHelp),
      (NoteStyle.casual, l10n.settingsNoteStyleCasual, l10n.settingsNoteStyleCasualHelp),
      (NoteStyle.custom, l10n.settingsNoteStyleCustom, null),
    ];
    final help = options.firstWhere((o) => o.$1 == _noteStyle).$3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            l10n.settingsNoteStyle,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (style, label, _) in options)
              ChoiceChip(
                label: Text(label),
                selected: _noteStyle == style,
                onSelected: (_) => setState(() => _noteStyle = style),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_noteStyle == NoteStyle.custom)
          TextField(
            controller: _noteStyleCustom,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 15, color: colors.onSurface),
            decoration: _fieldDecoration(l10n.settingsNoteStyleCustomLabel, colors).copyWith(
              hintText: l10n.settingsNoteStyleCustomHint,
              hintMaxLines: 3,
              helperText: l10n.settingsNoteStyleCustomHelp,
              helperMaxLines: 3,
              alignLabelWithHint: true,
            ),
          )
        else if (help != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(help, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          ),
      ],
    );
  }

  /// Provider segment button group in MD3 Expressive connected style:
  /// height 56 dp, 2 dp gap, outer radii 28 dp, inner radii 8 dp,
  /// with selected segment receiving full 28 dp rounding on all corners.
  Widget _providerConnectedButtonGroup(
      _TaskForm form, ColorScheme colors, AppLocalizations l10n) {
    // Provider names are proper names and stay untranslated; only "custom" is localized.
    final segments = [
      for (final preset in ProviderPreset.forTask(form.task))
        (
          preset: preset,
          label: switch (preset) {
            ProviderPreset.groq => 'Groq',
            ProviderPreset.openai => 'OpenAI',
            ProviderPreset.elevenlabs => 'ElevenLabs',
            ProviderPreset.gemini => 'Gemini',
            ProviderPreset.custom => l10n.settingsProviderCustom,
          },
        ),
    ];

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _providerSegmentItem(
                form: form,
                preset: segments[i].preset,
                label: segments[i].label,
                index: i,
                total: segments.length,
                isSelected: form.preset == segments[i].preset,
                colors: colors,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _providerSegmentItem({
    required _TaskForm form,
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
          onTap: () => setState(() => form.applyPreset(preset)),
          // Transcription offers five providers: on a phone a segment is ~70 dp, so a long
          // name scales down instead of wrapping or clipping.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
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
