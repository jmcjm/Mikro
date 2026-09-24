import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';
import 'chat_completion.dart';

/// Note produced by the model: a title pulled out of the leading `# heading` and the Markdown body
/// under it. [title] is `null` when the model skipped the heading — the caller picks a fallback.
class GeneratedNote {
  const GeneratedNote({required this.title, required this.content});

  final String? title;
  final String content;
}

class NotesApi {
  NotesApi(this._dio);

  final Dio _dio;

  /// Far above the tagging limit: tags only need the gist, a note is supposed to cover the whole
  /// recording. The cap only guards against pathological input — context windows and per-minute
  /// token quotas of small models are the practical limit, and exceeding them surfaces as an
  /// ordinary API error.
  static const _maxTranscriptChars = 48000;

  // English prompt for the same reason as in TaggingApi: the note language must follow the
  // transcript, not the instruction.
  static const _systemPrompt =
      'You turn a transcript of a voice recording into clean, well-structured notes in '
      'Markdown. Write in the same language as the transcript. Start with a single level-1 '
      'heading ("# ...") that is a short, specific title. Then organise the content with '
      'level-2 headings, bullet points and short paragraphs; use bold for key terms. If the '
      'transcript contains decisions, tasks or deadlines, list them in a separate section with '
      'task checkboxes ("- [ ] ..."). If it has speaker labels, attribute points to speakers '
      'where it matters. Keep every fact from the transcript that carries information, drop '
      'filler words and repetitions, and never add information that is not in the transcript. '
      'Return only the Markdown, without code fences or commentary.';

  Future<GeneratedNote> generate({
    required String transcript,
    required ProviderConfig config,
  }) async {
    final clipped = transcript.length > _maxTranscriptChars
        ? transcript.substring(0, _maxTranscriptChars)
        : transcript;
    final content = await chatCompletion(
      _dio,
      config: config,
      system: _systemPrompt,
      user: clipped,
      temperature: 0.2,
    );
    final note = parseNote(content);
    if (note == null) {
      throw MikroApiException(ApiErrorKind.noContent, 'empty note');
    }
    return note;
  }

  /// Strips a wrapping code fence (small models add one despite the prompt) and splits off the
  /// leading `# title`. `null` means the model returned nothing usable.
  static GeneratedNote? parseNote(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n?```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    if (s.isEmpty) return null;

    final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(s);
    // Only a heading at the very top is the title; a `#` further down is part of the structure.
    if (heading == null || heading.start != 0) return GeneratedNote(title: null, content: s);
    final title = heading.group(1)!.replaceAll(RegExp(r'\s*#+\s*$'), '').trim();
    final body = s.substring(heading.end).trim();
    return GeneratedNote(title: title.isEmpty ? null : title, content: body);
  }
}
