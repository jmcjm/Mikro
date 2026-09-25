import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_errors.dart';
import '../api/translation_api.dart';
import '../db/database.dart';
import '../models/provider_config.dart';
import '../models/translation_language.dart';
import '../notes/note_service.dart';
import '../settings/settings_repository.dart';

/// Translates transcripts and notes on request and stores the result next to the original.
/// Like [NoteService] this is an explicit user action, not a pipeline step: a failure never
/// touches the recording's status and there is nothing to resume.
class TranslationService {
  TranslationService({
    required this.db,
    required this.api,
    required this.settings,
    required this.prefs,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final TranslationApi api;
  final SettingsRepository settings;
  final SharedPreferences prefs;
  final DateTime Function() _clock;

  static const lastLanguageKey = 'translate_last_language';

  /// Language picked last time, offered first in the picker.
  String? get lastLanguage => prefs.getString(lastLanguageKey);

  /// Translates the recording's CURRENT transcript (manual edits included). Throws
  /// [NoConfigException] or [MikroApiException].
  Future<void> translateRecording(String recordingId, String language) async {
    final transcript = (await db.getRecording(recordingId))?.transcript;
    if (transcript == null || transcript.trim().isEmpty) {
      throw MikroApiException(ApiErrorKind.noTranscript, 'no transcript to translate');
    }
    final content = await _translate(transcript, language);
    await db.saveTranslation(
        recordingId: recordingId, language: language, content: content, now: _clock());
  }

  /// Translates title and body together, as one Markdown document with the title as its
  /// heading — the model then sees the whole context and the view renders it as it is.
  Future<void> translateNote(String noteId, String language) async {
    final note = await db.getNote(noteId);
    if (note == null) {
      throw MikroApiException(ApiErrorKind.noContent, 'note not found');
    }
    final source = note.title.trim().isEmpty ? note.content : '# ${note.title}\n\n${note.content}';
    final content = await _translate(source, language);
    await db.saveTranslation(noteId: noteId, language: language, content: content, now: _clock());
  }

  Future<String> _translate(String text, String language) async {
    final config = await settings.load(ApiTask.translate);
    if (config == null) throw NoConfigException();
    await prefs.setString(lastLanguageKey, language);
    return api.translate(text: text, target: TranslationLanguage.of(language), config: config);
  }
}
