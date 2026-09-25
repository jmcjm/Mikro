import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/notes_api.dart';
import 'api/tagging_api.dart';
import 'api/transcription_api.dart';
import 'audio/mikro_recorder.dart';
import 'db/database.dart';
import 'notes/note_service.dart';
import 'pipeline/processing_pipeline.dart';
import 'search/search_service.dart';
import 'settings/settings_repository.dart';

final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

final baseDirProvider =
    Provider<Directory>((ref) => throw UnimplementedError('override in main'));

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
    receiveTimeout: const Duration(minutes: 5),
  ));
  ref.onDispose(dio.close);
  return dio;
});

final keyStoreProvider = Provider<KeyStore>((ref) => SecureKeyStore());

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.watch(sharedPrefsProvider), ref.watch(keyStoreProvider)));

/// Bumped after every settings save. More than one settings screen can be alive at once (the
/// shell keeps one in its IndexedStack, onboarding pushes another), and each loads its form
/// only in initState — so they listen to this and reload, instead of showing and later
/// writing back the state from before someone else's save.
final settingsRevisionProvider = StateProvider<int>((ref) => 0);

final transcriptionApiProvider =
    Provider<TranscriptionApi>((ref) => TranscriptionApi(ref.watch(dioProvider)));

final taggingApiProvider = Provider<TaggingApi>((ref) => TaggingApi(ref.watch(dioProvider)));

final notesApiProvider = Provider<NotesApi>((ref) => NotesApi(ref.watch(dioProvider)));

final noteServiceProvider = Provider<NoteService>((ref) => NoteService(
      db: ref.watch(databaseProvider),
      notesApi: ref.watch(notesApiProvider),
      settings: ref.watch(settingsRepositoryProvider),
    ));

final recorderProvider = Provider<MikroRecorder>((ref) {
  final recorder = RecordPluginRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final pipelineProvider = Provider<ProcessingPipeline>((ref) => ProcessingPipeline(
      db: ref.watch(databaseProvider),
      transcriptionApi: ref.watch(transcriptionApiProvider),
      taggingApi: ref.watch(taggingApiProvider),
      settings: ref.watch(settingsRepositoryProvider),
    ));

final recordingsStreamProvider = StreamProvider<List<RecordingWithTags>>(
    (ref) => ref.watch(databaseProvider).watchAllWithTags());

final searchQueryProvider = StateProvider<String>((ref) => '');
final tagFilterProvider = StateProvider<String?>((ref) => null);
final searchServiceProvider = Provider<SearchService>((ref) => SearchService());

final filteredRecordingsProvider = Provider<List<RecordingWithTags>>((ref) {
  final all = ref.watch(recordingsStreamProvider).value ?? [];
  return ref.watch(searchServiceProvider).search(
        all,
        query: ref.watch(searchQueryProvider),
        tag: ref.watch(tagFilterProvider),
      );
});

final notesStreamProvider =
    StreamProvider<List<Note>>((ref) => ref.watch(databaseProvider).watchNotes());

final noteSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredNotesProvider = Provider<List<Note>>((ref) {
  final all = ref.watch(notesStreamProvider).value ?? [];
  return ref.watch(searchServiceProvider).searchNotes(all, query: ref.watch(noteSearchQueryProvider));
});
