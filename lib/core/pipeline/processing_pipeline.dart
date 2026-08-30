import 'dart:async';
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

  StreamSubscription<bool>? _connectivitySub;

  /// Ostatni znany stan łączności. Startujemy od `true`, bo pierwsze uruchomienie i tak
  /// przechodzi przez [resumePending] — dzięki temu samo wejście online przy starcie nie
  /// wywołuje drugiego, zbędnego wznowienia.
  bool _wasOnline = true;

  /// Strażnik przed nakładaniem się wznowień, gdy sieć mruga.
  bool _resuming = false;

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

  /// Podpina monitorowanie łączności. Wznowienie odpala się na ZBOCZU offline -> online,
  /// nie przy każdej emisji, więc utrzymujące się „online" nic nie robi.
  ///
  /// Przed zapętleniem przy mrugającej sieci chronią trzy rzeczy naraz i żadna nie wymaga
  /// zegara: wykrywanie zbocza (samo „online" nie wystarczy), flaga [_resuming] (kolejne
  /// zbocze w trakcie trwającego wznowienia jest pomijane) oraz istniejący dedup po `id`
  /// w [enqueue]. Dzięki temu zachowanie jest deterministyczne i testowalne bez czekania
  /// na upływ czasu.
  void bindConnectivity(Stream<bool> onlineChanges) {
    _connectivitySub?.cancel();
    _connectivitySub = onlineChanges.listen(_handleConnectivity);
  }

  /// Zatrzymuje monitorowanie łączności. Kolejka i trwające przetwarzanie zostają nietknięte.
  Future<void> stopWatchingConnectivity() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> _handleConnectivity(bool online) async {
    final regained = online && !_wasOnline;
    _wasOnline = online;
    if (!regained || _resuming) return;

    _resuming = true;
    try {
      // Najpierw nagrania, które utknęły konkretnie na sieci, potem cała zaległa kolejka.
      for (final recording in await db.networkFailedRecordings()) {
        enqueue(recording.id);
      }
      await resumePending();
    } catch (_) {
      // Wznawianie jest best-effort, tak samo jak przy starcie aplikacji.
    } finally {
      _resuming = false;
    }
  }

  Future<void> resumePending() async {
    try {
      for (final recording in await db.pendingRecordings()) {
        enqueue(recording.id);
      }
    } catch (_) {
      // Startup resume is best-effort; a dead DB at boot has nothing to resume.
      // Callers (main) fire this without awaiting, so a throw here would surface as an
      // unhandled async error on every launch.
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
      // Rodzaj bledu decyduje, czy warto ponowic po powrocie sieci — patrz networkFailedRecordings.
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: e.userMessage, errorKind: e.kind.name);
    } catch (e) {
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: 'Nieoczekiwany błąd: $e', errorKind: 'unknown');
    }
  }
}
