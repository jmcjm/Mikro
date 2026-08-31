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
  // Required by the MikroRecorder contract after the Task 8 dispose ruling.
  @override
  Future<void> dispose() async {}
}

// The settings screen from Task 13 reads configuration in initState, so without replacing
// the key store, the test would hit the flutter_secure_storage platform channel.
class FakeKeyStore implements KeyStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

void main() {
  testWidgets('app builds and has three tabs in Polish', (tester) async {
    // localesTestValue, not localeTestValue: WidgetsApp reads the `locales` list, not
    // a single `locale` — overriding the latter does not reach resolution.
    tester.platformDispatcher.localesTestValue = const [Locale('pl')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    // Onboarding flag is set — this test concerns the shell, not the first launch.
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

  // Locale resolution has two branches and only one of them is verified implicitly by
  // the rest of the tests. The second one — every language other than Polish falls back to English, not
  // the first in supportedLocales — has no other safeguard than this test.
  testWidgets('non-pl locale falls back to English, not the source language', (tester) async {
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

  testWidgets('first launch shows onboarding instead of shell', (tester) async {
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

    // The welcome blob animates continuously, so unmount the tree to ensure the ticker does not outlive the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
