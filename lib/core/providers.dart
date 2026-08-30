import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/tagging_api.dart';
import 'api/transcription_api.dart';
import 'audio/mikro_recorder.dart';
import 'db/database.dart';
import 'pipeline/processing_pipeline.dart';
import 'settings/settings_repository.dart';

final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

final baseDirProvider =
    Provider<Directory>((ref) => throw UnimplementedError('override in main'));

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
    )));

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
