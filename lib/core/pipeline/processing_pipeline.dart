import 'dart:async';
import 'dart:io';

import '../api/api_errors.dart';
import '../api/tagging_api.dart';
import '../api/transcription_api.dart';
import '../db/database.dart';
import '../models/recording_status.dart';
import '../settings/settings_repository.dart';

const maxUploadBytes = 25 * 1024 * 1024;

/// Rodzaje bledow zapisywane w kolumnie `errorKind` poza domena [ApiErrorKind]. Kolumna niesie
/// rodzaj, a nie gotowe zdanie: komunikat sklada dopiero UI w jezyku, ktory obowiazuje przy
/// ogladaniu, a nie w tym, ktory obowiazywal przy awarii. Wartosci sa czescia formatu bazy,
/// wiec nie zmieniaja sie razem z tekstami.
const errorKindNoConfig = 'noConfig';
const errorKindSizeLimit = 'sizeLimit';
const errorKindUnknown = 'unknown';

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

  /// Ostatni znany stan lacznosci; `null` znaczy "jeszcze nie ustalony". Rozroznienie jest
  /// istotne: sesja, ktora startuje juz z siecia, nie zobaczy zadnego zbocza offline -> online,
  /// wiec zastane bledy sieciowe musi wznowic rekoncyliacja startowa z [watchConnectivity].
  bool? _wasOnline;

  /// Straznik przed nakladaniem sie wznowien, gdy siec mruga.
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

  /// Wlacza reagowanie na lacznosc: nasluchuje zmian ORAZ uzgadnia stan zastany przy starcie.
  /// Jedyne wejscie uzywane w produkcji — obie sciezki koncza w tej samej [_resumeAll].
  ///
  /// Kolejnosc jest celowa: najpierw subskrypcja, dopiero potem odczyt, wiec zmiana lacznosci
  /// w trakcie odczytu nie ginie. Odczyt nie nadpisuje stanu, ktory zdazyl podac strumien
  /// (`??=`) — strumien jest swiezszy niz zapytanie wystartowane wczesniej.
  ///
  /// Podwojne wznowienie przy szybkim zbociu tuz po starcie odpada samo: [_resumeAll] pilnuje
  /// flagi [_resuming], a [enqueue] deduplikuje po `id`.
  Future<void> watchConnectivity({
    required Stream<bool> onlineChanges,
    required Future<bool> Function() isOnline,
  }) async {
    _bindConnectivity(onlineChanges);
    final bool online;
    try {
      online = await isOnline();
    } catch (_) {
      // Odczyt stanu lacznosci potrafi rzucic (brak uprawnien, kaprys platformy). Rekoncyliacja
      // startowa jest best-effort: nasluch zbocza juz dziala i wznowi, gdy siec wroci.
      return;
    }
    _wasOnline ??= online;
    if (online) await _resumeAll();
  }

  /// Podpina sam nasluch. Wznowienie odpala sie na ZBOCZU offline -> online, nie przy kazdej
  /// emisji, wiec utrzymujace sie "online" nic nie robi. Ponowne wywolanie zamyka poprzednia
  /// subskrypcje, zeby jeden pipeline nie sluchal dwoch zrodel naraz.
  ///
  /// Przed zapetleniem przy mrugajacej sieci chronia trzy rzeczy naraz i zadna nie wymaga
  /// zegara: wykrywanie zbocza (samo "online" nie wystarczy), flaga [_resuming] (kolejne
  /// zbocze w trakcie trwajacego wznowienia jest pomijane) oraz istniejacy dedup po `id`
  /// w [enqueue]. Dzieki temu zachowanie jest deterministyczne i testowalne bez czekania
  /// na uplyw czasu.
  void _bindConnectivity(Stream<bool> onlineChanges) {
    _connectivitySub?.cancel();
    _connectivitySub = onlineChanges.listen(_handleConnectivity);
  }

  Future<void> _handleConnectivity(bool online) async {
    final regained = online && _wasOnline == false;
    _wasOnline = online;
    if (!regained) return;
    await _resumeAll();
  }

  /// Jedyna sciezka wznawiania — wchodzi tu zarowno rekoncyliacja startowa, jak i zbocze
  /// powrotu sieci.
  Future<void> _resumeAll() async {
    if (_resuming) return;
    _resuming = true;
    try {
      // Najpierw nagrania, ktore utknely konkretnie na sieci, potem cala zalegla kolejka.
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
        await db.updateStatus(id, RecordingStatus.error, errorKind: errorKindNoConfig);
        return;
      }

      var transcript = recording.transcript;
      if (transcript == null) {
        final size = await File(recording.audioPath).length();
        if (size > maxUploadBytes) {
          await db.updateStatus(id, RecordingStatus.error, errorKind: errorKindSizeLimit);
          return;
        }
        await db.updateStatus(id, RecordingStatus.transcribing);
        transcript = await transcriptionApi.transcribe(audioPath: recording.audioPath, config: config);
        await db.setTranscript(id, transcript, config.sttModel);
      }
      await db.updateStatus(id, RecordingStatus.tagging);
      // Tytul i tagi powstaja w jednym wywolaniu modelu, wiec i zapisuja sie razem — dopiero
      // po nich nagranie przechodzi na `done`.
      final meta = await taggingApi.generateMeta(transcript: transcript, config: config);
      await db.setTitle(id, meta.title);
      await db.setTags(id, meta.tags);
      await db.updateStatus(id, RecordingStatus.done);
    } on MikroApiException catch (e) {
      // Rodzaj bledu decyduje, czy warto ponowic po powrocie sieci — patrz networkFailedRecordings.
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: e.message, errorKind: e.kind.name);
    } catch (e) {
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: '$e', errorKind: errorKindUnknown);
    }
  }
}
