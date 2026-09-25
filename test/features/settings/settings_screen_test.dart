import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_harness.dart';

class FakeKeyStore implements KeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String v) async => values[name] = v;
}

/// Phone frame dimensions from mockup. Default test surface (800x600) is shorter than
/// designed screen, so theme section fell below viewport and tapping card missed.
const _designFrame = Size(412, 892);

Future<SharedPreferences> pumpSettings(
  WidgetTester tester, {
  Map<String, Object> initial = const {},
  FakeKeyStore? keys,
}) async {
  await tester.binding.setSurfaceSize(_designFrame);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      keyStoreProvider.overrideWithValue(keys ?? FakeKeyStore()),
    ],
    child: localizedApp(const SettingsScreen()),
  ));
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  // Screen is entirely layout, so analyze won't catch layout issues — only building tree
  // catches Row overflows or invalid constraints. Each test builds the screen.
  testWidgets('theme section has six cards from mockup', (tester) async {
    await pumpSettings(tester);

    for (final label in ['Jasny', 'Ciemny', 'Dracula', 'Nord', 'Gruvbox', 'Systemowy']) {
      expect(find.text(label), findsOneWidget, reason: 'missing card $label');
    }
  });

  testWidgets('selecting card saves mode and palette to preferences', (tester) async {
    final prefs = await pumpSettings(tester);

    await tester.ensureVisible(find.text('Dracula'));
    await tester.tap(find.text('Dracula'));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_palette'), 'dracula');
    expect(prefs.getString('theme_mode'), 'dark');

    // Returning to baseline must reset both values, not just palette.
    await tester.ensureVisible(find.text(plL10n.settingsThemeSystem));
    await tester.tap(find.text(plL10n.settingsThemeSystem));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_palette'), 'md3');
    expect(prefs.getString('theme_mode'), 'system');
  });

  testWidgets('provider section shows fields and Groq preset', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Groq'), findsNWidgets(3));
    expect(find.text('OpenAI'), findsNWidgets(3));
    expect(find.text('Gemini'), findsNWidgets(3));
    expect(find.text('ElevenLabs'), findsOneWidget,
        reason: 'ElevenLabs has no chat API, so it is offered for transcription only');
    expect(find.text(plL10n.settingsProviderCustom), findsNWidgets(3));
    expect(find.text(plL10n.settingsSttSection), findsOneWidget);
    expect(find.text(plL10n.settingsTagsSection), findsOneWidget);
    expect(find.text(plL10n.settingsNotesSection), findsOneWidget);
    // Every section has its own address, key and model.
    expect(find.text(plL10n.settingsBaseUrl), findsNWidgets(3));
    expect(find.text(plL10n.settingsApiKey), findsNWidgets(3));
    expect(find.text(plL10n.settingsModel), findsNWidgets(3));
    // Missing stored configuration -> screen starts on Groq preset.
    expect(find.text('https://api.groq.com/openai/v1'), findsNWidgets(3));
  });

  testWidgets('API key is masked by default and can be revealed', (tester) async {
    await pumpSettings(tester);

    EditableText keyField() => tester.widget<EditableText>(
          find.byType(EditableText).at(1), // 0 is Base URL, 1 is API Key
        );

    expect(keyField().obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip(plL10n.settingsShowKey).first);
    await tester.tap(find.byTooltip(plL10n.settingsShowKey).first);
    await tester.pumpAndSettle();
    expect(keyField().obscureText, isFalse);
  });

  testWidgets('shows back button when pushed to Navigator and pops route on tap', (tester) async {
    await tester.binding.setSurfaceSize(_designFrame);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ],
      child: localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Tap Open Settings
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('does not show back button when opened at root (canPop = false)', (tester) async {
    await pumpSettings(tester);
    expect(find.byIcon(Symbols.arrow_back_rounded), findsNothing);
  });

  /// Text field by its current content — the three sections share labels.
  Finder fieldWith(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  testWidgets('sections are independent and save separately', (tester) async {
    final keys = FakeKeyStore();
    final prefs = await pumpSettings(tester, keys: keys);

    // Switch only the notes section to OpenAI: it is the third "OpenAI" segment.
    await tester.ensureVisible(find.text('OpenAI').at(2));
    await tester.tap(find.text('OpenAI').at(2));
    await tester.pumpAndSettle();
    expect(fieldWith('https://api.openai.com/v1'), findsOneWidget);
    expect(fieldWith('https://api.groq.com/openai/v1'), findsNWidgets(2));

    final keyFields = find.byWidgetPredicate((w) => w is TextField && w.obscureText);
    await tester.enterText(keyFields.at(0), 'gsk');
    await tester.enterText(keyFields.at(2), 'sk');
    await tester.ensureVisible(find.text(plL10n.settingsSave));
    await tester.tap(find.text(plL10n.settingsSave));
    await tester.pumpAndSettle();

    expect(prefs.getString('stt_base_url'), 'https://api.groq.com/openai/v1');
    expect(prefs.getString('stt_model'), 'whisper-large-v3-turbo');
    expect(prefs.getString('tags_base_url'), 'https://api.groq.com/openai/v1');
    expect(prefs.getString('notes_base_url'), 'https://api.openai.com/v1');
    expect(prefs.getString('notes_model'), 'gpt-4o-mini');
    expect(keys.values, {'api_key_stt': 'gsk', 'api_key_tags': '', 'api_key_notes': 'sk'});
  });

  // The shell keeps a SettingsScreen alive in its IndexedStack, and onboarding pushes another
  // one on top. A save in the pushed screen must reach the kept one, or the tab shows (and a
  // later save there writes back) the state from before the save.
  testWidgets('a save in one settings screen reloads the other live ones', (tester) async {
    final keys = FakeKeyStore();
    final prefs = await pumpSettings(tester, keys: keys);

    tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('OpenAI').first);
    await tester.tap(find.text('OpenAI').first);
    await tester.pumpAndSettle();
    final keyFields = find.byWidgetPredicate((w) => w is TextField && w.obscureText);
    await tester.enterText(keyFields.at(0), 'sk-nowy');
    await tester.ensureVisible(find.text(plL10n.settingsSave));
    await tester.tap(find.text(plL10n.settingsSave));
    await tester.pumpAndSettle();
    expect(prefs.getString('stt_base_url'), 'https://api.openai.com/v1');

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(fieldWith('https://api.openai.com/v1'), findsOneWidget);
    expect(fieldWith('sk-nowy'), findsOneWidget);
  });

  testWidgets('sampling switch: only for tags and notes, off by default, saves values',
      (tester) async {
    final prefs = await pumpSettings(tester);

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2), reason: 'transcription has no sampling control');
    expect(find.text(plL10n.settingsTemperature), findsNothing, reason: 'off by default');

    await tester.ensureVisible(switches.first);
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsTemperature), findsOneWidget);
    await tester.enterText(fieldWith('0').first, '0,5');

    await tester.ensureVisible(find.text(plL10n.settingsSave));
    await tester.tap(find.text(plL10n.settingsSave));
    await tester.pumpAndSettle();

    expect(prefs.getBool('tags_sampling_enabled'), isTrue);
    expect(prefs.getDouble('tags_temperature'), 0.5, reason: 'decimal comma accepted');
    expect(prefs.getDouble('tags_top_p'), 1);
    expect(prefs.getBool('notes_sampling_enabled'), isFalse);
  });

  testWidgets('settings saved before the split fill all three sections', (tester) async {
    await pumpSettings(
      tester,
      initial: {
        'base_url': 'http://localhost:8000/v1',
        'stt_model': 'whisper-lokalny',
        'tag_model': 'qwen',
      },
      keys: FakeKeyStore()..values['api_key'] = 'stary',
    );

    expect(fieldWith('http://localhost:8000/v1'), findsNWidgets(3));
    expect(fieldWith('stary'), findsNWidgets(3));
    expect(fieldWith('whisper-lokalny'), findsOneWidget);
    expect(fieldWith('qwen'), findsNWidgets(2), reason: 'notes inherit the tagging model');
  });

  testWidgets('note style: presets describe themselves, custom takes instructions',
      (tester) async {
    final prefs = await pumpSettings(tester);

    await tester.ensureVisible(find.text(plL10n.settingsNoteStyleDetailed));
    expect(find.text(plL10n.settingsNoteStyleDetailedHelp), findsOneWidget);

    await tester.tap(find.text(plL10n.settingsNoteStyleMeeting));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsNoteStyleMeetingHelp), findsOneWidget);

    await tester.tap(find.text(plL10n.settingsNoteStyleCustom));
    await tester.pumpAndSettle();
    final instructions = find.widgetWithText(TextField, plL10n.settingsNoteStyleCustomLabel);
    expect(instructions, findsOneWidget);
    await tester.enterText(instructions, 'Pisz jak do studenta.');

    await tester.ensureVisible(find.text(plL10n.settingsSave));
    await tester.tap(find.text(plL10n.settingsSave));
    await tester.pumpAndSettle();

    expect(prefs.getString('notes_style'), 'custom');
    expect(prefs.getString('notes_style_custom'), 'Pisz jak do studenta.');
  });

  testWidgets('five transcription providers fit a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 892));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ],
      child: localizedApp(const SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A RenderFlex overflow would have failed the pump above.
    await tester.tap(find.text('ElevenLabs'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'https://api.elevenlabs.io/v1'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'scribe_v2'), findsOneWidget);
  });
}
