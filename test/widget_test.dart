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
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('apka sie buduje i ma trzy taby', (tester) async {
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
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Nagrywaj'), findsOneWidget);
    expect(find.text('Biblioteka'), findsOneWidget);
    expect(find.text('Ustawienia'), findsOneWidget);

    // The library tab subscribes to a drift query stream, and IndexedStack builds every tab,
    // so that subscription is live for the whole test. When the ProviderScope is torn down,
    // drift schedules a zero-duration Timer to unregister the stream, which the binding then
    // reports as "A Timer is still pending". Unmounting here lets that timer be created while
    // the binding is still running. A bare pump() is not enough — the timer only fires once
    // virtual time actually advances.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
