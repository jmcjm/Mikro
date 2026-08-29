import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(String id) => db.insertRecording(
        id: id,
        createdAt: DateTime.utc(2026, 8, 29),
        durationMs: 1000,
        audioPath: '/tmp/$id.m4a',
      );

  test('insert ustawia status recorded', () async {
    await insert('a');
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.recorded);
    expect(r.transcript, isNull);
  });

  test('updateStatus z errorMessage i czyszczenie bledu', () async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'pad');
    expect((await db.getRecording('a'))!.errorMessage, 'pad');
    await db.updateStatus('a', RecordingStatus.transcribing);
    expect((await db.getRecording('a'))!.errorMessage, isNull);
  });

  test('setTranscript zapisuje tekst i providera', () async {
    await insert('a');
    await db.setTranscript('a', 'ala ma kota', 'whisper-1');
    final r = await db.getRecording('a');
    expect(r!.transcript, 'ala ma kota');
    expect(r.providerUsed, 'whisper-1');
  });

  test('setTags deduplikuje globalnie i linkuje', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['praca', 'notatki']);
    await db.setTags('b', ['praca']);
    final all = await db.watchAllWithTags().first;
    final tagsA = all.firstWhere((r) => r.recording.id == 'a').tags;
    final tagsB = all.firstWhere((r) => r.recording.id == 'b').tags;
    expect(tagsA, containsAll(['praca', 'notatki']));
    expect(tagsB, ['praca']);
  });

  test('deleteRecording kasuje powiazania i osierocone tagi', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['tylko-a', 'wspolny']);
    await db.setTags('b', ['wspolny']);
    await db.deleteRecording('a');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['b']);
    expect(all.first.tags, ['wspolny']); // 'tylko-a' sprzatniete
  });

  test('pendingRecordings zwraca stany niedokonczone', () async {
    await insert('a');
    await insert('b');
    await insert('c');
    await db.updateStatus('b', RecordingStatus.done);
    await db.updateStatus('c', RecordingStatus.tagging);
    final pending = (await db.pendingRecordings()).map((r) => r.id).toList();
    expect(pending, containsAll(['a', 'c']));
    expect(pending, isNot(contains('b')));
  });

  test('watchAllWithTags sortuje malejaco po dacie', () async {
    await db.insertRecording(id: 'old', createdAt: DateTime.utc(2026, 1, 1), durationMs: 1, audioPath: '/x');
    await db.insertRecording(id: 'new', createdAt: DateTime.utc(2026, 8, 1), durationMs: 1, audioPath: '/y');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['new', 'old']);
  });
}
