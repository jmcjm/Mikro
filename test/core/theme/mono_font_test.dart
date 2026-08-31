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

/// Phone frame size from mockup — settings screen overflows on default 800x600.
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
  // Font family spans three places: name in pubspec, constant in code, and files on disk. Desync
  // in any of them is silently ignored by Flutter — text simply falls back to default font — so
  // tests guard all three, not just the constant.
  group('monospace family', () {
    test('pubspec declares monoFontFamily with weight 400', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final start = pubspec.indexOf('family: $monoFontFamily');
      expect(start, isNot(-1), reason: 'pubspec does not declare family $monoFontFamily');

      final block = pubspec.substring(start);
      final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
          .allMatches(block)
          .map((match) => match.group(1)!)
          .toList();
      // Single weight because no style sets fontWeight on mono text — bundling
      // a second file would add ~38 KB that nothing references.
      expect(assets, hasLength(1), reason: 'expected single font weight');
      expect(block, contains('weight: 400'));

      for (final asset in assets) {
        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: 'missing font file $asset');
        // Empty or truncated file passes git just as silently as missing declaration.
        expect(file.lengthSync(), greaterThan(10 * 1024), reason: 'suspiciously small file $asset');
      }
    });

    test('font license sits alongside fonts', () {
      // OFL requires license text to accompany every copy of font.
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });

    test('technical captions in library use bundled family', () {
      final style = monoStyle(size: 13, color: const Color(0xFF000000));

      expect(style.fontFamily, monoFontFamily);
      expect(style.fontFamilyFallback, contains('monospace'));
    });

    testWidgets('technical fields in settings use bundled family', (tester) async {
      await pumpSettings(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final label in ['Base URL', 'Model STT', 'Model tagowania']) {
        final field = fields.firstWhere(
          (candidate) => candidate.decoration?.labelText == label,
          orElse: () => fail('missing field $label'),
        );
        expect(field.style?.fontFamily, monoFontFamily, reason: 'field $label is not mono');
        expect(field.style?.fontFamilyFallback, contains('monospace'), reason: 'field $label');
      }
    });
  });
}
