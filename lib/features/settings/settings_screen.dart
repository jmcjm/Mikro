import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/provider_config.dart';
import '../../core/providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_providers.dart';
import '../../l10n/app_localizations.dart';
import '../shell/home_tab.dart';

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

/// Dracula, Nord, Gruvbox, Catppuccin and Solarized are proper names — they remain identical across
/// languages and do not need ARB entries. Only the other three labels are localized, so the list is built
/// at build time rather than declared as a constant.
List<_ThemeChoice> _themeChoices(AppLocalizations l10n) => [
      _ThemeChoice(
          label: l10n.settingsThemeLight, mode: ThemeMode.light, palette: AppPalette.md3),
      _ThemeChoice(label: l10n.settingsThemeDark, mode: ThemeMode.dark, palette: AppPalette.md3),
      _ThemeChoice(label: 'Dracula', mode: ThemeMode.dark, palette: AppPalette.dracula),
      _ThemeChoice(label: 'Nord', mode: ThemeMode.dark, palette: AppPalette.nord),
      _ThemeChoice(label: 'Gruvbox', mode: ThemeMode.dark, palette: AppPalette.gruvbox),
      _ThemeChoice(
          label: 'Catppuccin Latte', mode: ThemeMode.light, palette: AppPalette.catppuccinLatte),
      _ThemeChoice(
          label: 'Catppuccin Frappé', mode: ThemeMode.dark, palette: AppPalette.catppuccinFrappe),
      _ThemeChoice(
          label: 'Catppuccin Macchiato',
          mode: ThemeMode.dark,
          palette: AppPalette.catppuccinMacchiato),
      _ThemeChoice(
          label: 'Catppuccin Mocha', mode: ThemeMode.dark, palette: AppPalette.catppuccinMocha),
      _ThemeChoice(
          label: 'Solarized Light', mode: ThemeMode.light, palette: AppPalette.solarized),
      _ThemeChoice(label: 'Solarized Dark', mode: ThemeMode.dark, palette: AppPalette.solarized),
      _ThemeChoice(
        label: l10n.settingsThemeSystem,
        mode: ThemeMode.system,
        palette: AppPalette.md3,
        icon: Symbols.brightness_auto_rounded,
      ),
    ];

/// Settings: a list of the AI services (one row each, showing provider and model) and the
/// theme grid. On a phone a service's form opens as a sub-page on tap; in the wide layout
/// the list stays on the left and the selected service's form fills the rest.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// Editable settings of one [ApiTask]: preset, address, key, model and sampling.
class _TaskForm {
  _TaskForm(this.task);

  final ApiTask task;
  final baseUrl = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController();
  ProviderPreset preset = ProviderPreset.groq;
  bool keyHidden = true;
  bool samplingEnabled = false;
  bool advancedOpen = false;
  double temperature = 0;
  double topP = 1;

  /// Transcription does not go through chat completions, so only the other tasks offer
  /// sampling control.
  bool get hasSampling => task != ApiTask.stt;

  /// The address is edited up front for a custom server; for a preset it is only shown,
  /// read-only, under "Advanced". Transcription on a custom server has nothing left there.
  bool get hasAdvanced => hasSampling || preset != ProviderPreset.custom;

  void load(ServiceConfig config, SamplingParams samplingValues) {
    baseUrl.text = config.baseUrl;
    apiKey.text = config.apiKey;
    model.text = config.model;
    preset = ProviderPreset.of(config.baseUrl);
    loadSampling(enabled: config.sampling != null, values: samplingValues);
  }

  /// Values are clamped to the slider ranges, which are the ranges the OpenAI API accepts.
  void loadSampling({required bool enabled, required SamplingParams values}) {
    samplingEnabled = enabled;
    temperature = values.temperature.clamp(0, maxTemperature).toDouble();
    topP = values.topP.clamp(0, maxTopP).toDouble();
  }

  static const maxTemperature = 2.0;
  static const maxTopP = 1.0;

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
        sampling: hasSampling && samplingEnabled
            ? SamplingParams(temperature: temperature, topP: topP)
            : null,
      );

  void dispose() {
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

  /// Service whose form is open: the sub-page on a phone (`null` shows the list), the right
  /// pane in the wide layout (`null` shows transcription there).
  ApiTask? _openTask;

  /// Theme section, for shortcuts that open Settings scrolled to it.
  final _themeKey = GlobalKey();
  var _themeScrollPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final form in _forms.values) {
      await _loadForm(form);
    }
    _loadNoteStyle();
    if (mounted) setState(() => _loaded = true);
    if (_themeScrollPending) _scrollToTheme();
  }

  Future<void> _loadForm(_TaskForm form) async {
    final repo = ref.read(settingsRepositoryProvider);
    final config = await repo.raw(form.task);
    // Nothing stored at all (fresh install) -> start from the Groq preset, as before.
    if (config.baseUrl.isEmpty) {
      form.applyPreset(ProviderPreset.groq);
      form.loadSampling(enabled: false, values: repo.samplingValues(form.task));
    } else {
      form.load(config, repo.samplingValues(form.task));
    }
  }

  void _loadNoteStyle() {
    final style = ref.read(settingsRepositoryProvider).loadNoteStyle();
    _noteStyle = style.style;
    _noteStyleCustom.text = style.custom;
  }

  /// Leaving a form without saving drops its edits, so the list never shows a provider or
  /// model that is not what the app actually uses.
  Future<void> _discard(ApiTask task) async {
    await _loadForm(_forms[task]!);
    if (task == ApiTask.notes) _loadNoteStyle();
    if (mounted) setState(() {});
  }

  void _openService(ApiTask task) {
    // In the wide layout another form is already showing; on a phone nothing is edited
    // while the list is up, so reloading transcription there changes nothing.
    final previous = _openTask ?? ApiTask.stt;
    setState(() => _openTask = task);
    if (previous != task) _discard(previous);
  }

  void _closeService() {
    final task = _openTask;
    if (task == null) return;
    setState(() => _openTask = null);
    _discard(task);
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

  /// Scrolls the theme section into view after the next frame, once it is laid out. Before
  /// the form has loaded there is no section yet, so the request waits for [_load].
  void _scrollToTheme() {
    if (!_loaded) {
      _themeScrollPending = true;
      return;
    }
    _themeScrollPending = false;
    if (!_wide) _closeService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _themeKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _save(ApiTask task) async {
    final repo = ref.read(settingsRepositoryProvider);
    // Taken before the awaits: this screen may be popped mid-save, and the others still
    // need to hear about it.
    final revision = ref.read(settingsRevisionProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppLocalizations.of(context).settingsSaved;
    await repo.save(task, _forms[task]!.value);
    if (task == ApiTask.notes) {
      await repo.saveNoteStyle(
          NoteStyleSetting(style: _noteStyle, custom: _noteStyleCustom.text.trim()));
    }
    revision.state++;
    messenger.showSnackBar(SnackBar(content: Text(saved)));
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
    ref.listen(settingsThemeRequestProvider, (_, _) => _scrollToTheme());
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final open = _openTask;
    final wide = _wide;

    final Widget body;
    if (wide) {
      final selected = open ?? ApiTask.stt;
      body = LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listPaneWidth(constraints.maxWidth),
              child: _listPage(colors, l10n, selected: selected),
            ),
            VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
            Expanded(child: _servicePage(_forms[selected]!, colors, l10n, wide: true)),
          ],
        ),
      );
    } else {
      body = open == null
          ? _listPage(colors, l10n)
          : _servicePage(_forms[open]!, colors, l10n, wide: false);
    }

    return PopScope(
      // System back on a phone sub-page returns to the list instead of leaving Settings.
      canPop: wide || open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeService();
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(child: body),
      ),
    );
  }

  /// [selected] marks the service shown next to the list in the wide layout.
  Widget _listPage(ColorScheme colors, AppLocalizations l10n, {ApiTask? selected}) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          title: l10n.settingsTitle,
          fontSize: 32,
          onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          colors: colors,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel(l10n.settingsServicesSection, colors),
                const SizedBox(height: 10),
                for (final (index, task) in ApiTask.values.indexed) ...[
                  if (index > 0) const SizedBox(height: 2),
                  _serviceTile(
                    _forms[task]!,
                    colors,
                    l10n,
                    first: index == 0,
                    last: index == ApiTask.values.length - 1,
                    selected: task == selected,
                  ),
                ],
                const SizedBox(height: 24),
                KeyedSubtree(key: _themeKey, child: _themeSection(colors, l10n)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header({
    required String title,
    required double fontSize,
    required VoidCallback? onBack,
    required ColorScheme colors,
  }) =>
      Padding(
        padding: EdgeInsets.fromLTRB(onBack != null ? 8 : 20, 16, 20, onBack != null ? 8 : 12),
        child: Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                icon: Icon(Symbols.arrow_back_rounded, color: colors.onSurface),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: _headerTitle(title, fontSize, colors)),
          ],
        ),
      );

  /// Screen title at 32 sp, sub-page title at 24 sp.
  Widget _headerTitle(String title, double fontSize, ColorScheme colors) => Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          height: fontSize == 32 ? 40 / 32 : 32 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: fontSize == 32 ? -0.5 : -0.3,
          color: colors.onSurface,
        ),
      );

  (String title, IconData icon) _service(ApiTask task, AppLocalizations l10n) => switch (task) {
        ApiTask.stt => (l10n.settingsSttTitle, Symbols.graphic_eq_rounded),
        ApiTask.tags => (l10n.settingsTagsTitle, Symbols.sell_rounded),
        ApiTask.notes => (l10n.settingsNotesTitle, Symbols.sticky_note_2_rounded),
        ApiTask.translate => (l10n.settingsTranslateTitle, Symbols.translate_rounded),
      };

  /// Provider names are proper names and stay untranslated; only "custom" is localized.
  String _presetLabel(ProviderPreset preset, AppLocalizations l10n) => switch (preset) {
        ProviderPreset.groq => 'Groq',
        ProviderPreset.openai => 'OpenAI',
        ProviderPreset.elevenlabs => 'ElevenLabs',
        ProviderPreset.gemini => 'Gemini',
        ProviderPreset.custom => l10n.settingsProviderCustom,
      };

  /// One service on the list: its name and "provider · model", opening the form on tap.
  /// Rows form one connected group: large outer radii, small inner ones.
  Widget _serviceTile(
    _TaskForm form,
    ColorScheme colors,
    AppLocalizations l10n, {
    required bool first,
    required bool last,
    required bool selected,
  }) {
    final (title, icon) = _service(form.task, l10n);
    final radius = BorderRadius.vertical(
      top: Radius.circular(first ? 20 : 4),
      bottom: Radius.circular(last ? 20 : 4),
    );
    final model = form.model.text.trim();
    final subtitleStyle = TextStyle(fontSize: 14, height: 20 / 14, color: colors.onSurfaceVariant);
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: colors.surfaceContainerHigh,
        onTap: () => _openService(form.task),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: colors.primaryContainer),
                  child: Icon(icon, fill: 1, size: 22, color: colors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_presetLabel(form.preset, l10n), style: subtitleStyle),
                          Text('  ·  ', style: subtitleStyle),
                          Expanded(
                            child: Text(
                              model.isEmpty ? '—' : model,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: subtitleStyle.copyWith(
                                fontSize: 13,
                                fontFamily: monoFontFamily,
                                fontFamilyFallback: monoFontFallback,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Symbols.chevron_right_rounded, size: 24, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The form of one service: a sub-page with a back button on a phone, the right pane in
  /// the wide layout.
  Widget _servicePage(_TaskForm form, ColorScheme colors, AppLocalizations l10n,
      {required bool wide}) {
    final (title, _) = _service(form.task, l10n);
    final isStt = form.task == ApiTask.stt;
    final side = wide ? 24.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: _headerTitle(title, 24, colors),
          )
        else
          _header(title: title, fontSize: 24, onBack: _closeService, colors: colors),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(side, 8, side, wide ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel(l10n.settingsProviderSection, colors),
                const SizedBox(height: 10),
                _providerConnectedButtonGroup(form, colors, l10n),
                if (form.preset == ProviderPreset.custom) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: form.baseUrl,
                    keyboardType: TextInputType.url,
                    style: _monoValueStyle(colors),
                    decoration: _fieldDecoration(l10n.settingsBaseUrl, colors)
                        .copyWith(hintText: 'https://'),
                  ),
                ],
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
                        form.keyHidden
                            ? Symbols.visibility_rounded
                            : Symbols.visibility_off_rounded,
                        fill: 1,
                        size: 22,
                      ),
                      color: colors.onSurfaceVariant,
                      tooltip: form.keyHidden ? l10n.settingsShowKey : l10n.settingsHideKey,
                    ),
                  ).copyWith(
                    // Every task but transcription may borrow the transcription key.
                    hintText: isStt ? null : l10n.settingsApiKeyInheritHint,
                    hintStyle: TextStyle(letterSpacing: 0, color: colors.onSurfaceVariant),
                    helperText: isStt ? null : l10n.settingsApiKeyInheritHelp,
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: form.model,
                  style: _monoValueStyle(colors),
                  decoration: _fieldDecoration(l10n.settingsModel, colors).copyWith(
                    helperText: isStt ? l10n.settingsSttModelHelp : null,
                    helperMaxLines: 3,
                  ),
                ),
                if (form.task == ApiTask.notes) ...[
                  const SizedBox(height: 22),
                  _noteStylePicker(colors, l10n),
                ],
                if (form.hasAdvanced) ...[
                  const SizedBox(height: 16),
                  _advancedSection(form, colors, l10n),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, 4, side, side),
          child: _saveButton(() => _save(form.task)),
        ),
      ],
    );
  }

  /// Collapsed by default: the address a preset sets and the sampling parameters are rarely
  /// touched, so they stay out of the way until asked for.
  Widget _advancedSection(_TaskForm form, ColorScheme colors, AppLocalizations l10n) {
    final summary = !form.hasSampling
        ? l10n.settingsBaseUrl
        : form.samplingEnabled
            ? l10n.settingsAdvancedSamplingValues(
                form.temperature.toStringAsFixed(2), form.topP.toStringAsFixed(2))
            : l10n.settingsAdvancedSamplingSummary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => setState(() => form.advancedOpen = !form.advancedOpen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsAdvanced,
                            style: TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: form.advancedOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Symbols.expand_more_rounded,
                          size: 24, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (form.advancedOpen)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (form.preset != ProviderPreset.custom)
                      TextField(
                        controller: form.baseUrl,
                        enabled: false,
                        style: _monoValueStyle(colors),
                        decoration: _fieldDecoration(l10n.settingsBaseUrlFromProvider, colors),
                      ),
                    if (form.hasSampling) ...[
                      if (form.preset != ProviderPreset.custom) const SizedBox(height: 6),
                      _samplingControl(form, colors, l10n),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Opt-in temperature and top_p. Off by default because some models (OpenAI's reasoning
  /// family) reject any non-default value with HTTP 400; off means neither is sent.
  Widget _samplingControl(_TaskForm form, ColorScheme colors, AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: form.samplingEnabled,
            onChanged: (on) => setState(() => form.samplingEnabled = on),
            title: Text(
              l10n.settingsSampling,
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
            ),
            subtitle: Text(
              l10n.settingsSamplingHelp,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
          if (form.samplingEnabled) ...[
            const SizedBox(height: 4),
            _samplingSlider(
              label: l10n.settingsTemperature,
              value: form.temperature,
              max: _TaskForm.maxTemperature,
              onChanged: (v) => setState(() => form.temperature = v),
              colors: colors,
            ),
            const SizedBox(height: 14),
            _samplingSlider(
              label: 'top_p',
              value: form.topP,
              max: _TaskForm.maxTopP,
              onChanged: (v) => setState(() => form.topP = v),
              colors: colors,
            ),
          ],
        ],
      );

  /// Slider in steps of 0.05, with its value and both ends of the range spelled out.
  Widget _samplingSlider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    required ColorScheme colors,
  }) {
    final mono = TextStyle(fontFamily: monoFontFamily, fontFamilyFallback: monoFontFallback);
    final rangeStyle = mono.copyWith(fontSize: 11, color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
              ),
              Text(value.toStringAsFixed(2),
                  style: mono.copyWith(fontSize: 14, color: colors.primary)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: SliderComponentShape.noOverlay,
              padding: EdgeInsets.zero,
            ),
            child: SizedBox(
              height: 44,
              child: Slider(
                value: value,
                max: max,
                divisions: (max / 0.05).round(),
                label: value.toStringAsFixed(2),
                semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
                onChanged: onChanged,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: rangeStyle),
              Text(max.toStringAsFixed(0), style: rangeStyle),
            ],
          ),
        ],
      ),
    );
  }

  /// Note style: four presets and "custom", whose text goes to the model as instructions.
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
        _sectionLabel(l10n.settingsNoteStyleSection, colors),
        const SizedBox(height: 8),
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
  /// height 48 dp, 2 dp gap, outer radii 24 dp, inner radii 8 dp,
  /// with selected segment receiving full rounding on all corners.
  Widget _providerConnectedButtonGroup(
      _TaskForm form, ColorScheme colors, AppLocalizations l10n) {
    final presets = ProviderPreset.forTask(form.task);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < presets.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _providerSegmentItem(
                form: form,
                preset: presets[i],
                label: _presetLabel(presets[i], l10n),
                index: i,
                total: presets.length,
                isSelected: form.preset == presets[i],
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
    const outer = Radius.circular(24);
    const inner = Radius.circular(8);
    final BorderRadius radius;
    if (isSelected) {
      radius = const BorderRadius.all(outer);
    } else if (index == 0) {
      radius = const BorderRadius.horizontal(left: outer, right: inner);
    } else if (index == total - 1) {
      radius = const BorderRadius.horizontal(left: inner, right: outer);
    } else {
      radius = const BorderRadius.all(inner);
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
        LayoutBuilder(builder: (context, constraints) {
          final columns = _themeColumns(constraints.maxWidth);
          return Column(
            children: [
              for (var row = 0; row < choices.length; row += columns) ...[
                if (row > 0) const SizedBox(height: _themeGap),
                Row(
                  children: [
                    for (var i = row; i < row + columns; i++) ...[
                      if (i > row) const SizedBox(width: _themeGap),
                      // The last row is padded with empty slots so its cards keep the
                      // same width as the ones above.
                      Expanded(
                        child: i < choices.length
                            ? _themeCard(
                                choices[i],
                                colors,
                                selected: choices[i].mode == mode &&
                                    choices[i].palette == palette,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  static const _themeGap = 10.0;

  /// Narrowest a theme card may get: three swatch dots plus padding, and room for a name
  /// such as "Macchiato" on one line.
  static const _themeCardMinWidth = 104.0;

  /// As many cards per row as fit at [_themeCardMinWidth], never fewer than two.
  static int _themeColumns(double width) =>
      ((width + _themeGap) / (_themeCardMinWidth + _themeGap)).floor().clamp(2, 12);

  Widget _themeCard(_ThemeChoice choice, ColorScheme colors, {required bool selected}) {
    // The selected card's border is 1 px thicker; the padding gives that pixel back, so the
    // name keeps the same width and does not wrap differently when the card is picked.
    final border = selected ? 2.0 : 1.0;
    final inset = 12 - border;
    const labelStyle = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _applyThemeChoice(choice),
      child: Container(
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? colors.surfaceContainerLow : null,
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (choice.icon case final icon?)
              Icon(icon, fill: 1, size: 16, color: colors.onSurfaceVariant)
            else
              _swatchDots(choice, colors),
            const SizedBox(height: 8),
            // Always two lines tall, name centred in them: every card, and so every row of
            // the grid, is the same height whether or not a name wraps.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(12) * labelStyle.height! * 2,
              child: Center(
                child: Text(
                  choice.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle.copyWith(color: colors.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _saveButton(VoidCallback onPressed) => SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
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
