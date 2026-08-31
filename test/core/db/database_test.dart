import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/api/api_errors.dart';
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

  test('insert sets recorded status', () async {
    await insert('a');
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.recorded);
    expect(r.transcript, isNull);
  });

  test('updateStatus with errorMessage and error clearing', () async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'pad');
    expect((await db.getRecording('a'))!.errorMessage, 'pad');
    await db.updateStatus('a', RecordingStatus.transcribing);
    expect((await db.getRecording('a'))!.errorMessage, isNull);
  });

  test('setTranscript persists text and provider', () async {
    await insert('a');
    await db.setTranscript('a', 'ala ma kota', 'whisper-1');
    final r = await db.getRecording('a');
    expect(r!.transcript, 'ala ma kota');
    expect(r.providerUsed, 'whisper-1');
  });

  test('setTags deduplicates globally and links', () async {
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

  test('deleteRecording deletes associations and orphan tags', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['tylko-a', 'wspolny']);
    await db.setTags('b', ['wspolny']);
    await db.deleteRecording('a');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['b']);
    expect(all.first.tags, ['wspolny']); // 'tylko-a' cleaned up
  });

  test('pendingRecordings returns unfinished states', () async {
    await insert('a');
    await insert('b');
    await insert('c');
    await db.updateStatus('b', RecordingStatus.done);
    await db.updateStatus('c', RecordingStatus.tagging);
    final pending = (await db.pendingRecordings()).map((r) => r.id).toList();
    expect(pending, containsAll(['a', 'c']));
    expect(pending, isNot(contains('b')));
  });

  test('watchAllWithTags sorts descending by date', () async {
    await db.insertRecording(id: 'old', createdAt: DateTime.utc(2026, 1, 1), durationMs: 1, audioPath: '/x');
    await db.insertRecording(id: 'new', createdAt: DateTime.utc(2026, 8, 1), durationMs: 1, audioPath: '/y');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['new', 'old']);
  });

  // --- Regression guards (Task 3, follow-up) ---
  // Tests in the plan verify cascade and orphan cleanup only via
  // watchAllWithTags(), and that query joins FROM the recordings table — orphan rows
  // are invisible to it, so it passes even if both mechanisms are completely disabled.
  // The tests below inspect the database state via direct SQL.

  test('GUARD: PRAGMA foreign_keys is enabled', () async {
    // SQLite ignores this pragma inside transactions, so beforeOpen can be a silent no-op.
    // Without this, the 1 cascade with KeyAction.cascade would never trigger.
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1, reason: 'FK cascades require PRAGMA foreign_keys = ON');
  });

  test('GUARD: deleteRecording does not leave orphans in recording_tags or tags', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['tylko-a', 'wspolny']);
    await db.setTags('b', ['wspolny']);

    final before = await db.customSelect('SELECT COUNT(*) c FROM recording_tags').getSingle();
    expect(before.data['c'], 3, reason: 'initial scenario: 2 links for a, 1 for b');

    await db.deleteRecording('a');

    final linksForA = await db
        .customSelect("SELECT COUNT(*) c FROM recording_tags WHERE recording_id = 'a'")
        .getSingle();
    expect(linksForA.data['c'], 0, reason: 'FK cascade must delete recording a links');

    final orphanLinks = await db.customSelect(
      'SELECT COUNT(*) c FROM recording_tags rt '
      'WHERE rt.recording_id NOT IN (SELECT id FROM recordings) '
      'OR rt.tag_id NOT IN (SELECT id FROM tags)',
    ).getSingle();
    expect(orphanLinks.data['c'], 0, reason: 'no recording_tags row may dangle');

    final tagNames = await db.customSelect('SELECT name FROM tags ORDER BY name').get();
    expect(
      tagNames.map((r) => r.data['name']).toList(),
      ['wspolny'],
      reason: 'tag tylko-a lost its last link and must be removed from tags table',
    );
  });

  // --- schema v2: errorKind (D2c) ---

  test('fresh database is version 4 and has error_kind, waveform, and title columns', () async {
    await insert('a');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await db.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']),
        containsAll(['error_kind', 'waveform', 'title']));
  });

  test('migration from v1 adds columns and does not lose existing recordings', () async {
    // This test does not use the database from setUp, and drift warns when two AppDatabase instances
    // coexist. We close it so the test log stays clean — tearDown will tolerate the second close().
    await db.close();

    // Database initialized manually in v1 shape (without error_kind, user_version = 1), so that drift
    // actually executes the onUpgrade path instead of creating the schema from scratch.
    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          'PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "error_message) VALUES ('stare', 0, 1000, '/stare.m4a', 'error', 'cos padlo')");
      rawDb.execute('PRAGMA user_version = 1');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migration must not lose existing recordings');
    expect(migrated!.errorMessage, 'cos padlo');
    expect(migrated.errorKind, isNull,
        reason: 'we do not know what kind of error it was, so it remains unrecognized');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4,
        reason: 'v1 database reaches current schema in a single open');

    // user_version alone proves nothing: drift bumps it upon leaving onUpgrade even
    // when no step added its column. Reading the recording will not catch this either,
    // as all new columns are nullable and a missing column looks like NULL.
    // Therefore we inspect the schema directly — this is the only assertion that fails if a migration step is missing.
    final columns = await legacy.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']),
        containsAll(['error_kind', 'waveform', 'title']),
        reason: 'v1 database must pass EVERY migration step, not just bump the version');
  });

  test('updateStatus saves errorKind and clears it when transitioning to non-error state',
      () async {
    await insert('a');

    await db.updateStatus('a', RecordingStatus.error,
        errorMessage: 'brak sieci', errorKind: 'network');
    expect((await db.getRecording('a'))!.errorKind, 'network');

    await db.updateStatus('a', RecordingStatus.transcribing);
    expect((await db.getRecording('a'))!.errorKind, isNull,
        reason: 'previous error kind must not survive the condition that caused it');
  });

  test('GUARD: networkErrorKind matches ApiErrorKind enum constant name', () {
    // Database predicates compare the column with text, and the pipeline writes
    // ApiErrorKind.network.name to it. Nothing in types links these two sides: renaming
    // the enum constant would leave queries that compile but match nothing.
    expect(AppDatabase.networkErrorKind, ApiErrorKind.network.name,
        reason: 'renaming the enum must update the constant used in predicates');
  });

  test('networkFailedRecordings returns only network errors', () async {
    await insert('siec');
    await insert('auth');
    await insert('wkolejce');
    await db.updateStatus('siec', RecordingStatus.error, errorKind: 'network');
    await db.updateStatus('auth', RecordingStatus.error, errorKind: 'auth');

    final ids = (await db.networkFailedRecordings()).map((r) => r.id);

    expect(ids, ['siec'],
        reason: 'auth error will fail the same way upon retry, so do not resume it when network returns');
  });

  test('watchQueueLength counts unfinished items together with network errors', () async {
    await insert('wkolejce');
    await insert('siec');
    await insert('auth');
    await insert('gotowe');
    await db.updateStatus('siec', RecordingStatus.error, errorKind: 'network');
    await db.updateStatus('auth', RecordingStatus.error, errorKind: 'auth');
    await db.updateStatus('gotowe', RecordingStatus.done);

    expect(await db.watchQueueLength().first, 2,
        reason: 'one waiting in queue, one stalled on network; auth and done do not count');
  });

  // --- schema v3: waveform (D2f) ---

  test('migration v2 -> v3 adds waveform, old recordings have NULL', () async {
    // As in v1 -> v2 test: close the setUp database so two instances do not coexist.
    await db.close();

    // Database in v2 shape (has error_kind, lacks waveform, user_version = 2), so drift
    // must take the onUpgrade path instead of building the schema from scratch.
    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          '"error_kind" TEXT NULL, PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "transcript) VALUES ('stare', 0, 1000, '/stare.m4a', 'done', 'stara notatka')");
      rawDb.execute('PRAGMA user_version = 2');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migration must not lose existing recordings');
    expect(migrated!.transcript, 'stara notatka');
    expect(migrated.waveform, isNull,
        reason: 'pre-v3 recordings were not measured, so there is nothing to draw');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await legacy.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']), contains('waveform'));
  });

  // --- manual tag editing ("+ tag" and chip deletion) ---

  test('addTag normalizes name and does not duplicate link', () async {
    await insert('a');
    await db.addTag('a', '  Spotkanie ');
    await db.addTag('a', 'SPOTKANIE');

    final all = await db.watchAllWithTags().first;
    expect(all.first.tags, ['spotkanie'],
        reason: 'same normalization as model tags: trim and lowercase');

    final links = await db.customSelect('SELECT COUNT(*) c FROM recording_tags').getSingle();
    expect(links.data['c'], 1, reason: 'second addition of the same name is a no-op');
  });

  test('removeTag removes link and cleans up tag without other recordings', () async {
    await insert('a');
    await db.setTags('a', ['spotkanie', 'release']);

    await db.removeTag('a', 'spotkanie');

    final all = await db.watchAllWithTags().first;
    expect(all.first.tags, ['release']);
    final tagNames = await db.customSelect('SELECT name FROM tags').get();
    expect(tagNames.map((r) => r.data['name']), ['release'],
        reason: 'tag without its last link must not remain in tags table');
  });

  test('removeTag preserves tag that still has other recordings', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['wspolny']);
    await db.setTags('b', ['wspolny']);

    await db.removeTag('a', 'wspolny');

    final all = await db.watchAllWithTags().first;
    expect(all.firstWhere((r) => r.recording.id == 'a').tags, isEmpty);
    expect(all.firstWhere((r) => r.recording.id == 'b').tags, ['wspolny'],
        reason: 'chip deletion applies to a single recording, not the entire library');
  });

  test('removeTag for unknown name is a no-op', () async {
    await insert('a');
    await db.setTags('a', ['spotkanie']);

    await db.removeTag('a', 'nie-ma-takiego');

    expect((await db.watchAllWithTags().first).first.tags, ['spotkanie']);
  });

  test('STREAM GUARD: watchAllWithTags emits new state after addTag and removeTag',
      () async {
    // Orphan tag cleanup in deleteRecording uses customStatement, which drift cannot
    // map to any table — such write does NOT invalidate streams. Manual tag editing must
    // therefore use typed queries, otherwise filter chips in the library would remain stale until next reload.
    await insert('a');
    final emissions = <List<String>>[];
    final sub = db.watchAllWithTags().listen((rows) => emissions.add([...rows.first.tags]));
    await pumpEventQueue();

    await db.addTag('a', 'spotkanie');
    await pumpEventQueue();

    await db.removeTag('a', 'spotkanie');
    await pumpEventQueue();

    await sub.cancel();
    expect(emissions, [
      <String>[],
      ['spotkanie'],
      <String>[],
    ]);
  });

  // --- schema v4: title (AI titles) ---

  test('migration v3 -> v4 adds title, old recordings have NULL', () async {
    // As in previous migrations: close the database from setUp so two instances do not coexist,
    // and set up database manually in v3 shape so drift must execute onUpgrade.
    await db.close();

    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          '"error_kind" TEXT NULL, "waveform" TEXT NULL, PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "transcript, waveform) VALUES ('stare', 0, 1000, '/stare.m4a', 'done', "
          "'stara notatka', '[0.1,0.5]')");
      rawDb.execute('PRAGMA user_version = 3');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migration must not lose existing recordings');
    expect(migrated!.transcript, 'stara notatka');
    expect(migrated.waveform, '[0.1,0.5]',
        reason: 'adding a column must not modify data from previous schemas');
    expect(migrated.title, isNull,
        reason: 'pre-v4 recordings had no titles, and we cannot guess title from transcript');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await legacy.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']), contains('title'));
  });

  test('setTitle saves title and allows clearing it', () async {
    await insert('a');
    expect((await db.getRecording('a'))!.title, isNull);

    await db.setTitle('a', 'Standup — przesuniecie release');
    expect((await db.getRecording('a'))!.title, 'Standup — przesuniecie release');

    await db.setTitle('a', null);
    expect((await db.getRecording('a'))!.title, isNull,
        reason: 'null must be written to database as NULL, not skipped in UPDATE');
  });

  test('insertRecording saves waveform, and leaves NULL without it', () async {
    await db.insertRecording(
      id: 'z-przebiegiem',
      createdAt: DateTime.utc(2026, 8, 29),
      durationMs: 1000,
      audioPath: '/a.m4a',
      waveform: '[0.1,0.5]',
    );
    await insert('bez-przebiegu');

    expect((await db.getRecording('z-przebiegiem'))!.waveform, '[0.1,0.5]');
    expect((await db.getRecording('bez-przebiegu'))!.waveform, isNull);
  });
}
