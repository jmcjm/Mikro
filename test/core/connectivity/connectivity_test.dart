import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/connectivity/connectivity_service.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/providers.dart';

class FakeConnectivityService implements ConnectivityService {
  final controller = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Stream<bool> get onlineChanges => controller.stream;

  @override
  Future<bool> isOnline() async => online;
}

void main() {
  test('online liczy sie, gdy jest cokolwiek poza none', () {
    // Urzadzenie potrafi raportowac kilka interfejsow naraz, np. wifi razem z VPN.
    expect(PluginConnectivityService.debugIsOnline([ConnectivityResult.none]), isFalse);
    expect(PluginConnectivityService.debugIsOnline([]), isFalse);
    expect(PluginConnectivityService.debugIsOnline([ConnectivityResult.wifi]), isTrue);
    expect(
        PluginConnectivityService.debugIsOnline(
            [ConnectivityResult.wifi, ConnectivityResult.vpn]),
        isTrue);
    expect(
        PluginConnectivityService.debugIsOnline(
            [ConnectivityResult.none, ConnectivityResult.mobile]),
        isTrue);
  });

  test('queueLengthProvider liczy niedokonczone i wstrzymane brakiem sieci', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    Future<void> insert(String id) => db.insertRecording(
        id: id, createdAt: DateTime.utc(2026), durationMs: 1, audioPath: '/x');

    await insert('wkolejce');
    await insert('siec');
    await insert('auth');
    await insert('gotowe');
    await db.updateStatus('siec', RecordingStatus.error, errorKind: 'network');
    await db.updateStatus('auth', RecordingStatus.error, errorKind: 'auth');
    await db.updateStatus('gotowe', RecordingStatus.done);

    final length = await container.read(queueLengthProvider.future);

    expect(length, 2,
        reason: 'jedno czeka w kolejce, jedno wisi na sieci; auth i done sie nie licza');
  });

  test('fake serwisu da sie podstawic pod provider', () async {
    final fake = FakeConnectivityService();
    addTearDown(fake.controller.close);
    final container = ProviderContainer(
        overrides: [connectivityServiceProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    expect(await container.read(connectivityServiceProvider).isOnline(), isTrue);
  });
}
