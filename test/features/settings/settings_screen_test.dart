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

/// Desktop frame from the wide-layout mockup.
const _desktopFrame = Size(1280, 800);

Future<SharedPreferences> pumpSettings(
  WidgetTester tester, {
  Map<String, Object> initial = const {},
  FakeKeyStore? keys,
  Size size = _designFrame,
}) async {
  setWindowSize(tester, size);
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        keyStoreProvider.overrideWithValue(keys ?? FakeKeyStore()),
      ],
      child: localizedApp(const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// Sets the window size MediaQuery reports (the wide layout switches on it) and the render
/// surface along with it.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens a service's form from the list.
Future<void> openService(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text(plL10n.settingsSave));
  await tester.tap(find.text(plL10n.settingsSave));
  await tester.pumpAndSettle();
}

Future<void> expandAdvanced(WidgetTester tester) async {
  await tester.ensureVisible(find.text(plL10n.settingsAdvanced));
  await tester.tap(find.text(plL10n.settingsAdvanced));
  await tester.pumpAndSettle();
}

/// Text field by its current content — the forms share labels.
Finder fieldWith(String text) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

final keyField = find.byWidgetPredicate((w) => w is TextField && w.obscureText);

void main() {
  // Screen is entirely layout, so analyze won't catch layout issues — only building tree
  // catches Row overflows or invalid constraints. Each test builds the screen.
  testWidgets('theme section has the mockup cards plus Catppuccin and Solarized', (tester) async {
    await pumpSettings(tester);

    for (final label in [
      'Jasny',
      'Ciemny',
      'Dracula',
      'Nord',
      'Gruvbox',
      'Catppuccin Latte',
      'Catppuccin Frappé',
      'Catppuccin Macchiato',
      'Catppuccin Mocha',
      'Solarized Light',
      'Solarized Dark',
      'Systemowy',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget, reason: 'missing card $label');
    }
  });

  testWidgets('cards per row follow the available width', (tester) async {
    double top(String label) => tester.getTopLeft(find.text(label, skipOffstage: false)).dy;

    await pumpSettings(tester); // 412 wide: three per row.
    expect(top('Dracula'), top('Jasny'));
    expect(top('Nord'), greaterThan(top('Jasny')));

    // Still the phone layout (below the wide breakpoint), so the grid gets the full width.
    setWindowSize(tester, const Size(800, 892));
    await tester.pumpAndSettle();
    expect(top('Nord'), top('Jasny'), reason: 'a wider screen fits more cards in a row');
  });

  testWidgets('a one-line card is centred next to a two-line one in its row', (tester) async {
    await pumpSettings(tester, size: const Size(800, 892));
    final oneLine = find.text('Gruvbox', skipOffstage: false);
    final twoLines = find.text('Catppuccin Latte', skipOffstage: false);
    expect(
      tester.getTopLeft(oneLine).dy,
      tester.getTopLeft(find.text('Jasny', skipOffstage: false)).dy,
    );
    expect(
      tester.getCenter(oneLine).dy,
      closeTo(tester.getCenter(twoLines).dy, 1),
      reason: 'the shorter content sits in the middle of the stretched card',
    );
  });

  testWidgets('every theme card is the same height, selected or not', (tester) async {
    await pumpSettings(tester);
    // A card is the InkWell around the name.
    double height(String label) => tester
        .getSize(find.ancestor(of: find.text(label, skipOffstage: false), matching: find.byType(InkWell)).first)
        .height;

    final oneLine = height('Nord');
    expect(height('Catppuccin Macchiato'), oneLine, reason: 'a two-line name does not stretch its card');
    expect(height('Systemowy'), oneLine, reason: 'the icon card matches the swatch cards');

    final label = find.text('Solarized Light');
    await tester.ensureVisible(label);
    final unselected = tester.getSize(label);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(height('Solarized Light'), oneLine, reason: 'the thicker selected border changes nothing');
    expect(tester.getSize(label), unselected, reason: 'the name wraps the same when selected');
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

  testWidgets('the list shows each service with its provider and model, no forms', (tester) async {
    await pumpSettings(tester);

    for (final title in [
      plL10n.settingsSttTitle,
      plL10n.settingsTagsTitle,
      plL10n.settingsNotesTitle,
      plL10n.settingsTranslateTitle,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // Missing stored configuration -> every service starts on the Groq preset.
    expect(find.text('Groq'), findsNWidgets(4));
    expect(find.text('whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('llama-3.1-8b-instant'), findsOneWidget);
    expect(find.text('llama-3.3-70b-versatile'), findsNWidgets(2));
    expect(find.byType(TextField), findsNothing);
    expect(find.text(plL10n.settingsSave), findsNothing, reason: 'saving belongs to a form');
  });

  testWidgets('a service page offers its providers; the address hides under Advanced', (
    tester,
  ) async {
    await pumpSettings(tester);

    await openService(tester, plL10n.settingsSttTitle);
    expect(find.text('ElevenLabs'), findsOneWidget);
    final url = fieldWith('https://api.groq.com/openai/v1');
    expect(url, findsNothing, reason: 'a preset sets the address, so it is not in the way');
    await expandAdvanced(tester);
    expect(url, findsOneWidget);
    expect(tester.widget<TextField>(url).enabled, isFalse);
    expect(
      find.byType(SwitchListTile),
      findsNothing,
      reason: 'transcription has no sampling control',
    );

    // A custom server needs the address, so it comes up front.
    await tester.tap(find.text(plL10n.settingsProviderCustom));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsBaseUrl), findsOneWidget);
    expect(
      find.text(plL10n.settingsAdvanced),
      findsNothing,
      reason: 'nothing left under Advanced for a custom transcription server',
    );

    await tester.tap(find.byIcon(Symbols.arrow_back_rounded));
    await tester.pumpAndSettle();
    await openService(tester, plL10n.settingsTagsTitle);
    expect(
      find.text('ElevenLabs'),
      findsNothing,
      reason: 'ElevenLabs has no chat API, so it is offered for transcription only',
    );
  });

  testWidgets('API key is masked by default and can be revealed', (tester) async {
    await pumpSettings(tester);
    await openService(tester, plL10n.settingsSttTitle);

    expect(keyField, findsOneWidget);
    await tester.tap(find.byTooltip(plL10n.settingsShowKey));
    await tester.pumpAndSettle();
    expect(keyField, findsNothing);
  });

  testWidgets('shows back button when pushed to Navigator and pops route on tap', (tester) async {
    setWindowSize(tester, _designFrame);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          keyStoreProvider.overrideWithValue(FakeKeyStore()),
        ],
        child: localizedApp(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

  testWidgets('back from a service page returns to the list, system back too', (tester) async {
    await pumpSettings(tester);

    await openService(tester, plL10n.settingsNotesTitle);
    expect(find.text(plL10n.settingsNoteStyleSection), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsServicesSection), findsOneWidget);

    await openService(tester, plL10n.settingsNotesTitle);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsServicesSection), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'Settings itself stays open');
  });

  testWidgets('a service saves on its own; the others stay untouched', (tester) async {
    final keys = FakeKeyStore();
    final prefs = await pumpSettings(tester, keys: keys);

    await openService(tester, plL10n.settingsNotesTitle);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(keyField, 'sk');
    await save(tester);

    expect(prefs.getString('notes_base_url'), 'https://api.openai.com/v1');
    expect(prefs.getString('notes_model'), 'gpt-4o-mini');
    expect(prefs.getString('stt_base_url'), isNull);
    expect(prefs.getString('tags_base_url'), isNull);
    expect(keys.values, {'api_key_notes': 'sk'});

    await tester.tap(find.byIcon(Symbols.arrow_back_rounded));
    await tester.pumpAndSettle();
    // Translation has never been saved, so it still follows the notes settings.
    expect(find.text('OpenAI'), findsNWidgets(2), reason: 'the list shows the saved provider');
    expect(find.text('gpt-4o-mini'), findsNWidgets(2));
  });

  testWidgets('leaving a service page without saving drops its edits', (tester) async {
    final prefs = await pumpSettings(tester);

    await openService(tester, plL10n.settingsNotesTitle);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(plL10n.settingsNoteStyleMeeting));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsNothing);
    expect(find.text('Groq'), findsNWidgets(4));
    await openService(tester, plL10n.settingsNotesTitle);
    expect(fieldWith('llama-3.3-70b-versatile'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, plL10n.settingsNoteStyleDetailed))
          .selected,
      isTrue,
    );
    expect(prefs.getString('notes_base_url'), isNull);
  });

  // The shell keeps a SettingsScreen alive in its IndexedStack, and onboarding pushes another
  // one on top. A save in the pushed screen must reach the kept one, or the tab shows (and a
  // later save there writes back) the state from before the save.
  testWidgets('a save in one settings screen reloads the other live ones', (tester) async {
    final keys = FakeKeyStore();
    final prefs = await pumpSettings(tester, keys: keys);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();

    await openService(tester, plL10n.settingsSttTitle);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(keyField, 'sk-nowy');
    await save(tester);
    expect(prefs.getString('stt_base_url'), 'https://api.openai.com/v1');

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('whisper-1'), findsOneWidget);
    await openService(tester, plL10n.settingsSttTitle);
    expect(fieldWith('sk-nowy'), findsOneWidget);
  });

  testWidgets('sampling: off by default, sliders when on, values saved', (tester) async {
    final prefs = await pumpSettings(tester);
    await openService(tester, plL10n.settingsTagsTitle);

    expect(find.text(plL10n.settingsAdvancedSamplingSummary), findsOneWidget);
    await expandAdvanced(tester);
    expect(find.byType(Slider), findsNothing, reason: 'off by default');

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text(plL10n.settingsAdvancedSamplingValues('0.00', '1.00')), findsOneWidget);

    // The middle of the 0–2 track is 1.
    final temperature = find.byType(Slider).first;
    await tester.ensureVisible(temperature);
    await tester.tapAt(tester.getCenter(temperature));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsAdvancedSamplingValues('1.00', '1.00')), findsOneWidget);

    await save(tester);
    expect(prefs.getBool('tags_sampling_enabled'), isTrue);
    expect(prefs.getDouble('tags_temperature'), 1);
    expect(prefs.getDouble('tags_top_p'), 1);
    expect(prefs.getBool('notes_sampling_enabled'), isNull, reason: 'notes were not saved');
  });

  testWidgets('settings saved before the split fill every service', (tester) async {
    await pumpSettings(
      tester,
      initial: {
        'base_url': 'http://localhost:8000/v1',
        'stt_model': 'whisper-lokalny',
        'tag_model': 'qwen',
      },
      keys: FakeKeyStore()..values['api_key'] = 'stary',
    );

    expect(find.text(plL10n.settingsProviderCustom), findsNWidgets(4));
    expect(find.text('whisper-lokalny'), findsOneWidget);
    expect(
      find.text('qwen'),
      findsNWidgets(3),
      reason: 'notes inherit the tagging model, translation inherits notes',
    );

    await openService(tester, plL10n.settingsSttTitle);
    expect(fieldWith('http://localhost:8000/v1'), findsOneWidget);
    expect(fieldWith('stary'), findsOneWidget);
  });

  testWidgets('note style: presets describe themselves, custom takes instructions', (tester) async {
    final prefs = await pumpSettings(tester);
    await openService(tester, plL10n.settingsNotesTitle);

    expect(find.text(plL10n.settingsNoteStyleDetailedHelp), findsOneWidget);

    await tester.tap(find.text(plL10n.settingsNoteStyleMeeting));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsNoteStyleMeetingHelp), findsOneWidget);

    await tester.tap(find.text(plL10n.settingsNoteStyleCustom));
    await tester.pumpAndSettle();
    final instructions = find.widgetWithText(TextField, plL10n.settingsNoteStyleCustomLabel);
    expect(instructions, findsOneWidget);
    await tester.enterText(instructions, 'Pisz jak do studenta.');
    await save(tester);

    expect(prefs.getString('notes_style'), 'custom');
    expect(prefs.getString('notes_style_custom'), 'Pisz jak do studenta.');
  });

  testWidgets('five transcription providers fit a narrow phone', (tester) async {
    await pumpSettings(tester, size: const Size(360, 892));
    await openService(tester, plL10n.settingsSttTitle);

    // A RenderFlex overflow would have failed the pumps above.
    await tester.tap(find.text('ElevenLabs'));
    await tester.pumpAndSettle();
    expect(fieldWith('scribe_v2'), findsOneWidget);
    await expandAdvanced(tester);
    expect(fieldWith('https://api.elevenlabs.io/v1'), findsOneWidget);
  });

  testWidgets('wide layout: the list stays next to the selected service form', (tester) async {
    final prefs = await pumpSettings(tester, size: _desktopFrame);

    // Transcription is shown until another service is picked; no back button in the pane.
    expect(find.text(plL10n.settingsServicesSection), findsOneWidget);
    expect(find.text('ElevenLabs'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back_rounded), findsNothing);
    expect(find.text('Dracula'), findsOneWidget, reason: 'themes stay in the left column');

    await tester.tap(find.text(plL10n.settingsNotesTitle));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.settingsNoteStyleSection), findsOneWidget);
    expect(find.text('ElevenLabs'), findsNothing);

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(prefs.getString('notes_base_url'), 'https://api.openai.com/v1');
    expect(
      find.text('gpt-4o-mini'),
      findsNWidgets(3),
      reason: 'model field, the notes row and the translation row that follows notes',
    );
  });
}
