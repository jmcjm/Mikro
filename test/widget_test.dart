import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/app.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/providers.dart';
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
      ],
      child: const MikroApp(),
    ));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Nagrywaj'), findsOneWidget);
    expect(find.text('Biblioteka'), findsOneWidget);
    expect(find.text('Ustawienia'), findsOneWidget);
  });
}
