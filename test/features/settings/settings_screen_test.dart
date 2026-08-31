import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_harness.dart';

class FakeKeyStore implements KeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;
}

/// Phone frame dimensions from mockup. Default test surface (800x600) is shorter than
/// designed screen, so theme section fell below viewport and tapping card missed.
const _designFrame = Size(412, 892);

Future<SharedPreferences> pumpSettings(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_designFrame);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

    expect(find.text('Groq'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text(plL10n.settingsProviderCustom), findsOneWidget);
    expect(find.text(plL10n.settingsBaseUrl), findsOneWidget);
    expect(find.text(plL10n.settingsApiKey), findsOneWidget);
    expect(find.text(plL10n.settingsSttModel), findsOneWidget);
    expect(find.text(plL10n.settingsTagModel), findsOneWidget);
    // Missing stored configuration -> screen starts on Groq preset.
    expect(find.text('https://api.groq.com/openai/v1'), findsOneWidget);
  });

  testWidgets('API key is masked by default and can be revealed', (tester) async {
    await pumpSettings(tester);

    EditableText keyField() => tester.widget<EditableText>(
          find.byType(EditableText).at(1), // 0 is Base URL, 1 is API Key
        );

    expect(keyField().obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip(plL10n.settingsShowKey));
    await tester.tap(find.byTooltip(plL10n.settingsShowKey));
    await tester.pumpAndSettle();
    expect(keyField().obscureText, isFalse);
  });
}
