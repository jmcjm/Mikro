import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/core/theme/app_theme.dart';
import 'package:mikro/features/library/library_styles.dart';
import 'package:mikro/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_harness.dart';

class _FakeKeyStore implements KeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;
}

/// Rozmiar ramki telefonu z makiety — na domyslnych 800x600 ekran ustawien sie nie miesci.
const _designFrame = Size(412, 892);

Future<void> pumpSettings(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_designFrame);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      keyStoreProvider.overrideWithValue(_FakeKeyStore()),
    ],
    child: localizedApp(const SettingsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // Rodzina fontu laczy trzy miejsca: nazwe w pubspecu, stala w kodzie i pliki na dysku. Rozjazd
  // ktoregokolwiek z nich Flutter zjada bez slowa — tekst po prostu wraca na font domyslny — wiec
  // testy pilnuja calej trojki, a nie samej stalej.
  group('rodzina monospace', () {
    test('pubspec deklaruje monoFontFamily w wagach 400 i 500', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final start = pubspec.indexOf('family: $monoFontFamily');
      expect(start, isNot(-1), reason: 'pubspec nie deklaruje rodziny $monoFontFamily');

      final block = pubspec.substring(start);
      final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
          .allMatches(block)
          .map((match) => match.group(1)!)
          .toList();
      expect(assets, hasLength(2), reason: 'oczekiwane dwie wagi fontu');
      expect(block, contains('weight: 400'));
      expect(block, contains('weight: 500'));

      for (final asset in assets) {
        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: 'brak pliku fontu $asset');
        // Pusty albo skrocony plik przechodzi przez git tak samo cicho jak brak deklaracji.
        expect(file.lengthSync(), greaterThan(10 * 1024), reason: 'podejrzanie maly plik $asset');
      }
    });

    test('licencja fontu lezy razem z fontami', () {
      // OFL wymaga, zeby tekst licencji szedl z kazda kopia fontu.
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });

    test('podpisy techniczne biblioteki uzywaja zbundlowanej rodziny', () {
      final style = monoStyle(size: 13, color: const Color(0xFF000000));

      expect(style.fontFamily, monoFontFamily);
      expect(style.fontFamilyFallback, contains('monospace'));
    });

    testWidgets('pola techniczne ustawien uzywaja zbundlowanej rodziny', (tester) async {
      await pumpSettings(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final label in ['Base URL', 'Model STT', 'Model tagowania']) {
        final field = fields.firstWhere(
          (candidate) => candidate.decoration?.labelText == label,
          orElse: () => fail('brak pola $label'),
        );
        expect(field.style?.fontFamily, monoFontFamily, reason: 'pole $label nie jest mono');
        expect(field.style?.fontFamilyFallback, contains('monospace'), reason: 'pole $label');
      }
    });
  });
}
