import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/tagging_api.dart';
import 'api/transcription_api.dart';
import 'audio/mikro_recorder.dart';
import 'db/database.dart';
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

final transcriptionApiProvider =
    Provider<TranscriptionApi>((ref) => TranscriptionApi(ref.watch(dioProvider)));

final taggingApiProvider = Provider<TaggingApi>((ref) => TaggingApi(ref.watch(dioProvider)));

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
