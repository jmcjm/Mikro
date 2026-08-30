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

/// Rozmiar ramki telefonu z makiety. Domyslna powierzchnia testowa (800x600) jest nizsza niz
/// projektowany ekran, wiec sekcja motywu wypadala poza widok i stuk w karte nie trafial.
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
  // Ekran jest w calosci ukladem, wiec analyze go nie sprawdzi — dopiero zbudowanie drzewa
  // wylapie przepelnienie wiersza albo bledne ograniczenia. Kazdy z tych testow buduje ekran.
  testWidgets('sekcja motywu ma szesc kart z makiety', (tester) async {
    await pumpSettings(tester);

    for (final label in ['Jasny', 'Ciemny', 'Dracula', 'Nord', 'Gruvbox', 'Systemowy']) {
      expect(find.text(label), findsOneWidget, reason: 'brak karty $label');
    }
  });

  testWidgets('wybor karty zapisuje tryb i palete do preferencji', (tester) async {
    final prefs = await pumpSettings(tester);

    await tester.ensureVisible(find.text('Dracula'));
    await tester.tap(find.text('Dracula'));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_palette'), 'dracula');
    expect(prefs.getString('theme_mode'), 'dark');

    // Powrot na baseline musi cofnac obie wartosci, nie tylko palete.
    await tester.ensureVisible(find.text(plL10n.settingsThemeSystem));
    await tester.tap(find.text(plL10n.settingsThemeSystem));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_palette'), 'md3');
    expect(prefs.getString('theme_mode'), 'system');
  });

  testWidgets('sekcja providera pokazuje pola i preset Groq', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Groq'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text(plL10n.settingsProviderCustom), findsOneWidget);
    expect(find.text(plL10n.settingsBaseUrl), findsOneWidget);
    expect(find.text(plL10n.settingsApiKey), findsOneWidget);
    expect(find.text(plL10n.settingsSttModel), findsOneWidget);
    expect(find.text(plL10n.settingsTagModel), findsOneWidget);
    // Brak zapisanej konfiguracji -> ekran startuje na presecie Groq.
    expect(find.text('https://api.groq.com/openai/v1'), findsOneWidget);
  });

  testWidgets('klucz API jest domyslnie zamaskowany i da sie go odslonic', (tester) async {
    await pumpSettings(tester);

    EditableText keyField() => tester.widget<EditableText>(
          find.byType(EditableText).at(1), // 0 to Base URL, 1 to Klucz API
        );

    expect(keyField().obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip(plL10n.settingsShowKey));
    await tester.tap(find.byTooltip(plL10n.settingsShowKey));
    await tester.pumpAndSettle();
    expect(keyField().obscureText, isFalse);
  });
}
