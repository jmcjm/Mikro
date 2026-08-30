import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/app.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/onboarding/onboarding_providers.dart';
import 'package:mikro/features/onboarding/onboarding_screen.dart';
import 'package:mikro/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/l10n_harness.dart';

class FakeRecorder implements MikroRecorder {
  @override
  String get fileExtension => 'm4a';
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<double> amplitude() => const Stream.empty();
  // Wymagane przez kontrakt MikroRecorder po rulingu dispose z Taska 8.
  @override
  Future<void> dispose() async {}
}

// Ekran ustawien z Taska 13 czyta konfiguracje w initState, wiec bez podmiany
// magazynu klucza test wpadlby na kanal platformowy flutter_secure_storage.
class FakeKeyStore implements KeyStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

void main() {
  testWidgets('apka sie buduje i ma trzy taby po polsku', (tester) async {
    // localesTestValue, nie localeTestValue: WidgetsApp czyta liste `locales`, a nie
    // pojedyncze `locale` — podmiana tego drugiego nie dociera do rezolucji.
    tester.platformDispatcher.localesTestValue = const [Locale('pl')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    // Flaga onboardingu podniesiona — ten test dotyczy powloki, nie pierwszego uruchomienia.
    SharedPreferences.setMockInitialValues({onboardingCompletedKey: true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        baseDirProvider.overrideWithValue(Directory.systemTemp),
        databaseProvider.overrideWithValue(db),
        recorderProvider.overrideWithValue(FakeRecorder()),
        keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ],
      child: const MikroApp(),
    ));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(plL10n.navRecord), findsOneWidget);
    expect(find.text(plL10n.navLibrary), findsOneWidget);
    expect(find.text(plL10n.navSettings), findsOneWidget);

    // The library tab subscribes to a drift query stream, and IndexedStack builds every tab,
    // so that subscription is live for the whole test. When the ProviderScope is torn down,
    // drift schedules a zero-duration Timer to unregister the stream, which the binding then
    // reports as "A Timer is still pending". Unmounting here lets that timer be created while
    // the binding is still running. A bare pump() is not enough — the timer only fires once
    // virtual time actually advances.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // Rezolucja locale ma dwie galezie i tylko jedna z nich sprawdza sie sama przy okazji
  // reszty testow. Ta druga — kazdy jezyk poza polskim schodzi na angielski, a nie na
  // pierwszy z supportedLocales — nie ma innego strazniku niz ten test.
  testWidgets('locale spoza pl schodzi na angielski, nie na jezyk zrodlowy', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues({onboardingCompletedKey: true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        baseDirProvider.overrideWithValue(Directory.systemTemp),
        databaseProvider.overrideWithValue(db),
        recorderProvider.overrideWithValue(FakeRecorder()),
        keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ],
      child: const MikroApp(),
    ));
    await tester.pump();

    final en = AppLocalizationsEn();
    expect(find.text(en.navRecord), findsOneWidget);
    expect(find.text(plL10n.navRecord), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pierwsze uruchomienie pokazuje onboarding zamiast powloki', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        baseDirProvider.overrideWithValue(Directory.systemTemp),
        databaseProvider.overrideWithValue(db),
        recorderProvider.overrideWithValue(FakeRecorder()),
        keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ],
      child: const MikroApp(),
    ));
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Blob powitania animuje sie w kolko, wiec zdejmujemy drzewo, zeby ticker nie przezyl testu.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
