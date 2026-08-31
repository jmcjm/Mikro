import 'dart:async';
import 'dart:io';

import '../api/api_errors.dart';
import '../api/tagging_api.dart';
import '../api/transcription_api.dart';
import '../db/database.dart';
import '../models/recording_status.dart';
import '../settings/settings_repository.dart';

const maxUploadBytes = 25 * 1024 * 1024;

/// Error kinds stored in the `errorKind` column outside the [ApiErrorKind] domain. The column holds
/// error kinds rather than ready-made sentences: the message is assembled by the UI in the user's
/// active language at view time, not the locale present at failure time. Values are part of the
/// database schema format and do not change with UI copy.
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

  /// Last known connectivity state; `null` means "not yet resolved". The distinction is
  /// important: a session starting already online will not observe an offline -> online edge,
  /// so existing network errors must be resumed via initial reconciliation in [watchConnectivity].
  bool? _wasOnline;

  /// Guard against overlapping resumes when network connectivity fluctuates.
  bool _resuming = false;

  Future<void> get idle => _queue;

  void enqueue(String recordingId) {
    if (!_inFlight.add(recordingId)) return;
    // catchError keeps the queue alive even if _process throws unexpectedly
    // (e.g., if updateStatus itself failed in a catch block). Without this, a single rejected future
    // would propagate to every subsequent chained item, permanently stalling the pipeline.
    _queue = _queue
        .then((_) => _process(recordingId).whenComplete(() => _inFlight.remove(recordingId)))
        .catchError((Object _) {});
  }

  /// Enables connectivity responsiveness: listens for changes AND reconciles the initial startup state.
  /// The single entry point used in production — both paths converge in [_resumeAll].
  ///
  /// The order is intentional: subscribe first, then query initial state, ensuring connectivity transitions
  /// during the query are not missed. The query does not overwrite a state already reported by the stream
  /// (`??=`) — the stream event is fresher than a previously initiated query.
  ///
  /// Duplicate resumption from a rapid edge right after startup is prevented automatically: [_resumeAll] checks
  /// the [_resuming] flag, and [enqueue] deduplicates by `id`.
  Future<void> watchConnectivity({
    required Stream<bool> onlineChanges,
    required Future<bool> Function() isOnline,
  }) async {
    _bindConnectivity(onlineChanges);
    final bool online;
    try {
      online = await isOnline();
    } catch (_) {
      // Reading connectivity state can throw (lack of permissions, platform quirks). Initial
      // reconciliation is best-effort: edge listener is already active and will resume once network returns.
      return;
    }
    _wasOnline ??= online;
    if (online) await _resumeAll();
  }

  /// Attaches the connectivity listener. Resumption triggers on an offline -> online EDGE, not on every
  /// emission, so continuous "online" events perform no action. Re-invoking cancels any prior
  /// subscription to ensure a single pipeline does not listen to multiple sources simultaneously.
  ///
  /// Flapping network loops are prevented by three concurrent mechanisms without relying on timers:
  /// edge detection (plain "online" is insufficient), the [_resuming] flag (subsequent edges
  /// during an ongoing resume are skipped), and existing `id` deduplication in [enqueue].
  /// This keeps behavior deterministic and testable without waiting on real-time delays.
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

  /// Single resume execution path — entered by both initial startup reconciliation and online transition edges.
  Future<void> _resumeAll() async {
    if (_resuming) return;
    _resuming = true;
    try {
      // First process recordings that stalled specifically due to network issues, then the rest of the pending queue.
      for (final recording in await db.networkFailedRecordings()) {
        enqueue(recording.id);
      }
      await resumePending();
    } catch (_) {
      // Resumption is best-effort, consistent with application startup.
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
    // Loading recording and config must also be wrapped in try: settings.load() reads secrets
    // from system storage (libsecret / Keystore), which can throw. Outside try, such exceptions
    // would escape _process, leave the recording stuck in recorded state without an error message, and poison the queue.
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
      // Title and tags are generated in a single model call and saved together — only after
      // both succeed does the recording advance to `done`.
      final meta = await taggingApi.generateMeta(transcript: transcript, config: config);
      await db.setTitle(id, meta.title);
      await db.setTags(id, meta.tags);
      await db.updateStatus(id, RecordingStatus.done);
    } on MikroApiException catch (e) {
      // Error kind determines whether retry is worthwhile upon network reconnection — see networkFailedRecordings.
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: e.message, errorKind: e.kind.name);
    } catch (e) {
      await db.updateStatus(id, RecordingStatus.error,
          errorMessage: '$e', errorKind: errorKindUnknown);
    }
  }
}
