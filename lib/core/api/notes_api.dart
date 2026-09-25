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

  // English prompt for the same reason as in TaggingApi: the note language must follow the
  // transcript, not the instruction.
  //
  // Split in two. The format rules are fixed — the app depends on them (the leading heading
  // becomes the note title, fences would break rendering), so no style may override them. The
  // style part is what the user picks in settings, custom text included.
  static const _formatRules =
      'You turn a transcript of a voice recording into notes in Markdown. Write in the same '
      'language as the transcript. Start with a single level-1 heading ("# ...") that is a '
      'short, specific title. If the transcript has speaker labels, attribute points to '
      'speakers where it matters. Never add information that is not in the transcript. Return '
      'only the Markdown, without code fences or commentary.';

  static const _styles = {
    NoteStyle.detailed:
        'Style: detailed, well-structured notes. Organise the content with level-2 headings, '
        'bullet points and short paragraphs; use bold for key terms. Keep every fact that '
        'carries information, drop filler words and repetitions. If the transcript contains '
        'decisions, tasks or deadlines, list them in a separate section with task checkboxes '
        '("- [ ] ...").',
    NoteStyle.concise:
        'Style: a concise summary. At most a few short bullet points with the essentials, '
        'then, only if there are any, a short list of tasks as checkboxes ("- [ ] ..."). No '
        'sub-headings, no background detail — something readable in under a minute.',
    NoteStyle.meeting:
        'Style: meeting minutes. Sections, in this order and only when the transcript has '
        'material for them: participants, topics discussed (a short summary per topic), '
        'decisions, action items as checkboxes ("- [ ] owner — task — deadline", with owner and '
        'deadline only when stated), open questions.',
  };

  /// Style part of the system prompt. Custom instructions that are empty fall back to the
  /// detailed style — an empty instruction would leave the model with no guidance on shape.
  static String styleInstructions(NoteStyle style, String custom) {
    if (style == NoteStyle.custom) {
      final text = custom.trim();
      if (text.isNotEmpty) return 'Style instructions from the user: $text';
      return _styles[NoteStyle.detailed]!;
    }
    return _styles[style]!;
  }

  Future<GeneratedNote> generate({
    required String transcript,
    required ServiceConfig config,
    NoteStyle style = NoteStyle.detailed,
    String customStyle = '',
  }) async {
    final content = await chatCompletion(
      _dio,
      config: config,
      system: '$_formatRules\n\n${styleInstructions(style, customStyle)}',
      user: transcript,
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
