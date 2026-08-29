import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/recording_status.dart';

part 'database.g.dart';

class Recordings extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get audioPath => text()();
  TextColumn get status => textEnum<RecordingStatus>()();
  TextColumn get transcript => text().nullable()();
  TextColumn get providerUsed => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class RecordingTags extends Table {
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {recordingId, tagId};
}

class RecordingWithTags {
  RecordingWithTags({required this.recording, required this.tags});

  final Recording recording;
  final List<String> tags;
}

@DriftDatabase(tables: [Recordings, Tags, RecordingTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'mikro'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> insertRecording({
    required String id,
    required DateTime createdAt,
    required int durationMs,
    required String audioPath,
  }) =>
      into(recordings).insert(RecordingsCompanion.insert(
        id: id,
        createdAt: createdAt,
        durationMs: durationMs,
        audioPath: audioPath,
        status: RecordingStatus.recorded,
      ));

  Future<Recording?> getRecording(String id) =>
      (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(String id, RecordingStatus status, {String? errorMessage}) =>
      (update(recordings)..where((r) => r.id.equals(id))).write(
        RecordingsCompanion(status: Value(status), errorMessage: Value(errorMessage)),
      );

  Future<void> setTranscript(String id, String transcript, String providerUsed) =>
      (update(recordings)..where((r) => r.id.equals(id))).write(
        RecordingsCompanion(transcript: Value(transcript), providerUsed: Value(providerUsed)),
      );

  Future<void> setTags(String recordingId, List<String> names) => transaction(() async {
        for (final name in names) {
          await into(tags).insert(TagsCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
          final tag = await (select(tags)..where((t) => t.name.equals(name))).getSingle();
          await into(recordingTags).insert(
            RecordingTagsCompanion.insert(recordingId: recordingId, tagId: tag.id),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });

  Future<void> deleteRecording(String id) => transaction(() async {
        await (delete(recordings)..where((r) => r.id.equals(id))).go();
        await customStatement(
            'DELETE FROM tags WHERE id NOT IN (SELECT DISTINCT tag_id FROM recording_tags)');
      });

  Future<List<Recording>> pendingRecordings() => (select(recordings)
        ..where((r) => r.status.isInValues(
            [RecordingStatus.recorded, RecordingStatus.transcribing, RecordingStatus.tagging])))
      .get();

  Stream<List<RecordingWithTags>> watchAllWithTags() {
    final query = select(recordings).join([
      leftOuterJoin(recordingTags, recordingTags.recordingId.equalsExp(recordings.id)),
      leftOuterJoin(tags, tags.id.equalsExp(recordingTags.tagId)),
    ])
      ..orderBy([OrderingTerm.desc(recordings.createdAt)]);
    return query.watch().map((rows) {
      final byId = <String, RecordingWithTags>{};
      final order = <String>[];
      for (final row in rows) {
        final rec = row.readTable(recordings);
        final tag = row.readTableOrNull(tags);
        final entry = byId.putIfAbsent(rec.id, () {
          order.add(rec.id);
          return RecordingWithTags(recording: rec, tags: []);
        });
        if (tag != null) entry.tags.add(tag.name);
      }
      return [for (final id in order) byId[id]!];
    });
  }
}
