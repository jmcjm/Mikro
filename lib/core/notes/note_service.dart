import 'package:uuid/uuid.dart';

import '../api/api_errors.dart';
import '../api/notes_api.dart';
import '../db/database.dart';
import '../models/provider_config.dart';
import '../settings/settings_repository.dart';

/// Raised when there is no provider configured — the UI points the user to settings instead of
/// showing an API error.
class NoConfigException implements Exception {}

/// Creates notes from recordings. Kept out of the processing pipeline on purpose: a note is an
/// explicit user action ("make a note"), not a processing step, so a failure here never marks
/// the recording as broken and there is nothing to resume after a restart.
class NoteService {
  NoteService({
    required this.db,
    required this.notesApi,
    required this.settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final NotesApi notesApi;
  final SettingsRepository settings;
  final DateTime Function() _clock;

  /// Generates a note from the recording's CURRENT transcript (including manual edits) and
  /// returns the new note's id. Throws [NoConfigException] or [MikroApiException].
  Future<String> createFromRecording(String recordingId) async {
    final recording = await db.getRecording(recordingId);
    final transcript = recording?.transcript;
    if (recording == null || transcript == null || transcript.trim().isEmpty) {
      throw MikroApiException(ApiErrorKind.noTranscript, 'no transcript to summarise');
    }
    final config = await settings.load(ApiTask.notes);
    if (config == null) throw NoConfigException();

    final style = settings.loadNoteStyle();
    final generated = await notesApi.generate(
      transcript: transcript,
      config: config,
      style: style.style,
      customStyle: style.custom,
    );
    final id = const Uuid().v4();
    await db.insertNote(
      id: id,
      recordingId: recordingId,
      title: generated.title ?? recording.title ?? '',
      content: generated.content,
      now: _clock(),
    );
    return id;
  }

  /// Rewrites an existing note from its source transcript, keeping its id and link. The user's
  /// edits are lost — the UI confirms before calling this.
  Future<void> regenerate(String noteId) async {
    final note = await db.getNote(noteId);
    final recordingId = note?.recordingId;
    final recording = recordingId == null ? null : await db.getRecording(recordingId);
    final transcript = recording?.transcript;
    if (note == null || transcript == null || transcript.trim().isEmpty) {
      throw MikroApiException(ApiErrorKind.noTranscript, 'no source transcript');
    }
    final config = await settings.load(ApiTask.notes);
    if (config == null) throw NoConfigException();

    final style = settings.loadNoteStyle();
    final generated = await notesApi.generate(
      transcript: transcript,
      config: config,
      style: style.style,
      customStyle: style.custom,
    );
    await db.updateNote(
      noteId,
      title: generated.title ?? note.title,
      content: generated.content,
      now: _clock(),
    );
  }
}
