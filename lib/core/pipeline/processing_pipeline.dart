import 'dart:io';

import '../api/api_errors.dart';
import '../api/tagging_api.dart';
import '../api/transcription_api.dart';
import '../db/database.dart';
import '../models/recording_status.dart';
import '../settings/settings_repository.dart';

const maxUploadBytes = 25 * 1024 * 1024;

class ProcessingPipeline {
  ProcessingPipeline({
    required this.db,
    required this.transcriptionApi,
    required this.taggingApi,
    required this.settings,
  });

  final AppDatabase db;
  final TranscriptionApi transcriptionApi;
  final TaggingApi taggingApi;
  final SettingsRepository settings;

  Future<void> _queue = Future.value();
  final Set<String> _inFlight = {};

  Future<void> get idle => _queue;

  void enqueue(String recordingId) {
    if (!_inFlight.add(recordingId)) return;
    // catchError trzyma kolejke przy zyciu nawet wtedy, gdy _process rzuci mimo wszystko
    // (np. gdyby zawiodl sam updateStatus w bloku catch). Bez tego jedna odrzucona przyszlosc
    // propaguje sie na kazde kolejne ogniwo i pipeline jest martwy do konca zycia procesu.
    _queue = _queue
        .then((_) => _process(recordingId).whenComplete(() => _inFlight.remove(recordingId)))
        .catchError((Object _) {});
  }

  Future<void> resumePending() async {
    for (final recording in await db.pendingRecordings()) {
      enqueue(recording.id);
    }
  }

  Future<void> _process(String id) async {
    // Odczyt nagrania i konfiguracji tez musi byc w try: settings.load() siega po klucz do
    // magazynu systemowego (libsecret / Keystore), ktory potrafi rzucic. Poza try taki wyjatek
    // uciekal z _process, zostawial nagranie w stanie recorded bez komunikatu i zatruwal kolejke.
    try {
      final recording = await db.getRecording(id);
      if (recording == null || recording.status == RecordingStatus.done) return;

      final config = await settings.load();
      if (config == null) {
        await db.updateStatus(id, RecordingStatus.error,
            errorMessage: 'Brak konfiguracji API — ustaw klucz w Ustawieniach.');
        return;
      }

      var transcript = recording.transcript;
      if (transcript == null) {
        final size = await File(recording.audioPath).length();
        if (size > maxUploadBytes) {
          await db.updateStatus(id, RecordingStatus.error,
              errorMessage: 'Nagranie przekracza limit 25 MB — za długie do transkrypcji.');
          return;
        }
        await db.updateStatus(id, RecordingStatus.transcribing);
        transcript = await transcriptionApi.transcribe(audioPath: recording.audioPath, config: config);
        await db.setTranscript(id, transcript, config.sttModel);
      }
      await db.updateStatus(id, RecordingStatus.tagging);
      final tags = await taggingApi.generateTags(transcript: transcript, config: config);
      await db.setTags(id, tags);
      await db.updateStatus(id, RecordingStatus.done);
    } on MikroApiException catch (e) {
      await db.updateStatus(id, RecordingStatus.error, errorMessage: e.userMessage);
    } catch (e) {
      await db.updateStatus(id, RecordingStatus.error, errorMessage: 'Nieoczekiwany błąd: $e');
    }
  }
}
