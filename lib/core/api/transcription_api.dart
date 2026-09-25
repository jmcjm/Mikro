import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

/// Upload limit of OpenAI-compatible `/audio/transcriptions` (OpenAI and Groq both cap at 25 MB).
const maxUploadBytes = 25 * 1024 * 1024;

/// Gemini takes the audio inline, base64-encoded, and caps the WHOLE request at 20 MB. Base64
/// inflates by 4/3, so ~14.5 MB of audio is the ceiling; the margin covers prompt and JSON.
const geminiMaxUploadBytes = 14 * 1024 * 1024;

/// ElevenLabs accepts files up to gigabytes; the practical limit is what the phone can send.
const elevenLabsMaxUploadBytes = 1024 * 1024 * 1024;

/// Largest recording [config]'s provider accepts — checked before uploading anything, so an
/// oversized file fails fast with a clear message instead of a slow upload and a 413.
int uploadLimitFor(ServiceConfig config) => switch (ProviderPreset.of(config.baseUrl).sttProtocol) {
  SttProtocol.openai => maxUploadBytes,
  SttProtocol.gemini => geminiMaxUploadBytes,
  SttProtocol.elevenlabs => elevenLabsMaxUploadBytes,
};

class TranscriptionApi {
  TranscriptionApi(this._dio);

  final Dio _dio;

  /// Speaker diarization on the OpenAI protocol is a property of the model, not a switch on the
  /// endpoint: Whisper (OpenAI, Groq) has no notion of speakers at all, while OpenAI's
  /// `gpt-4o-transcribe-diarize` returns them only in the `diarized_json` format. Detecting it by
  /// name keeps the settings free of a toggle that would silently do nothing for other models.
  /// ElevenLabs and Gemini always get speakers — see their request builders.
  static bool supportsDiarization(String model) => model.toLowerCase().contains('diarize');

  /// Wire format is picked from the address: the ElevenLabs and Gemini presets have their own,
  /// anything else — Groq, OpenAI, a self-hosted server — speaks OpenAI's.
  Future<String> transcribe({required String audioPath, required ServiceConfig config}) async {
    try {
      return switch (ProviderPreset.of(config.baseUrl).sttProtocol) {
        SttProtocol.openai => await _openai(audioPath, config),
        SttProtocol.elevenlabs => await _elevenLabs(audioPath, config),
        SttProtocol.gemini => await _gemini(audioPath, config),
      };
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<String> _openai(String audioPath, ServiceConfig config) async {
    final diarize = supportsDiarization(config.model);
    final form = FormData.fromMap({
      'model': config.model,
      'file': await MultipartFile.fromFile(audioPath),
      if (diarize) ...{
        'response_format': 'diarized_json',
        // Required by the diarizing model for anything longer than 30 s.
        'chunking_strategy': 'auto',
      },
    });
    final response = await _dio.post<dynamic>(
      '${config.baseUrl}/audio/transcriptions',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
    );
    final data = _object(response.data);
    if (diarize) {
      final labelled = formatDiarizedSegments(data['segments']);
      if (labelled != null) return labelled;
    }
    return _text(data['text']);
  }

  /// ElevenLabs Scribe. Diarization is always requested: it costs nothing extra and a single
  /// speaker simply comes back unlabelled (see [labelTurns]).
  Future<String> _elevenLabs(String audioPath, ServiceConfig config) async {
    final form = FormData.fromMap({
      'model_id': config.model,
      'file': await MultipartFile.fromFile(audioPath),
      'diarize': 'true',
      // Speaker ids ride on word entries, so words must be returned.
      'timestamps_granularity': 'word',
      'tag_audio_events': 'false',
    });
    final response = await _dio.post<dynamic>(
      '${config.baseUrl}/speech-to-text',
      data: form,
      options: Options(headers: {'xi-api-key': config.apiKey}),
    );
    final data = _object(response.data);
    return formatElevenLabsWords(data['words']) ?? _text(data['text']);
  }

  // English prompt for the same reason as in the chat prompts: the output language must follow
  // the recording, and an explicit "do not translate" keeps the model from drifting to English.
  static const _geminiPrompt =
      'Transcribe this audio recording verbatim, in the language(s) actually spoken; do not '
      'translate, summarise or correct the speakers. If more than one person speaks, start '
      'every change of speaker on a new paragraph prefixed with a label: "A: ", "B: " and so '
      'on, in order of first appearance. If only one person speaks, use no labels at all. '
      'Return only the transcript text, with no headings, timestamps or commentary. If there '
      'is no speech, return an empty response.';

  /// Gemini through the native `generateContent`: its OpenAI-compatible layer has no
  /// `/audio/transcriptions`. The preset stores the OpenAI-compatible address (shared with tags
  /// and notes), so the native root is that address without its `/openai` suffix.
  Future<String> _gemini(String audioPath, ServiceConfig config) async {
    final bytes = await File(audioPath).readAsBytes();
    final root = config.baseUrl.replaceFirst(RegExp(r'/openai/?$'), '');
    final response = await _dio.post<dynamic>(
      '$root/models/${config.model}:generateContent',
      data: {
        'contents': [
          {
            'parts': [
              {'text': _geminiPrompt},
              {
                'inline_data': {'mime_type': 'audio/m4a', 'data': base64Encode(bytes)},
              },
            ],
          },
        ],
        'generationConfig': {'temperature': 0},
      },
      options: Options(headers: {'x-goog-api-key': config.apiKey}),
    );
    return _text(geminiText(_object(response.data)));
  }

  /// Type casting to Map is done explicitly. If generic `post<Map<String, dynamic>>` did it,
  /// dio would wrap _TypeError in a DioException without response, and mapDioError would classify
  /// it as a network failure — the user would see "No network connection." instead of an API error.
  static Map<String, dynamic> _object(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw MikroApiException(ApiErrorKind.badFormat, 'response body is not an object');
    }
    return data;
  }

  static String _text(Object? text) {
    if (text is! String) {
      throw MikroApiException(ApiErrorKind.noTranscript, 'no text field in response');
    }
    return text;
  }

  /// Concatenated text of `candidates[0].content.parts`, or `null` for any other shape.
  static String? geminiText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    final texts = [
      for (final part in parts)
        if (part is Map && part['text'] is String) part['text'] as String,
    ];
    return texts.isEmpty ? null : texts.join().trim();
  }

  /// OpenAI `diarized_json` segments to labelled text. `null` for anything that is not a usable
  /// segment list; the caller falls back to `text`.
  static String? formatDiarizedSegments(Object? segments) {
    if (segments is! List) return null;
    return labelTurns([
      for (final segment in segments)
        if (segment is Map && segment['text'] is String)
          ('${segment['speaker'] ?? '?'}', (segment['text'] as String).trim()),
    ]);
  }

  /// ElevenLabs `words` (words and the spacing between them, each with a `speaker_id`) to
  /// labelled text. Spacing is kept as returned, so the text reads exactly as transcribed.
  static String? formatElevenLabsWords(Object? words) {
    if (words is! List) return null;
    final pieces = <(String, String)>[];
    String? speaker;
    for (final word in words) {
      if (word is! Map || word['text'] is! String) continue;
      final type = word['type'];
      if (type != 'word' && type != 'spacing') continue; // audio events: (laughter) etc.
      // Spacing belongs to whoever spoke before it; only words switch the speaker.
      if (type == 'word') speaker = '${word['speaker_id'] ?? '?'}';
      pieces.add((speaker ?? '?', word['text'] as String));
    }
    // Spacing arrives as its own entries, so pieces are concatenated as they are.
    return labelTurns(pieces, joiner: '');
  }

  /// Joins `(speaker, text)` pieces into turns: one paragraph per change of speaker, labelled
  /// `A:`, `B:` … in order of first appearance, whatever ids the provider uses (`speaker_0`,
  /// `A`, …). Consecutive pieces of one speaker merge — providers split on pauses, and a new
  /// label every sentence is noise.
  ///
  /// A recording with a single speaker comes back WITHOUT labels: "A:" in front of a solo voice
  /// memo carries no information. The result is plain transcript text either way, so renaming
  /// "A" to a real name is just editing the transcript.
  static String? labelTurns(List<(String, String)> pieces, {String joiner = ' '}) {
    final turns = <(String, StringBuffer)>[];
    for (final (speaker, text) in pieces) {
      final continues = turns.isNotEmpty && turns.last.$1 == speaker;
      // An empty piece never opens a turn — it would become an empty labelled paragraph.
      if (!continues && text.trim().isEmpty) continue;
      if (continues) {
        turns.last.$2
          ..write(joiner)
          ..write(text);
      } else {
        turns.add((speaker, StringBuffer(text)));
      }
    }
    if (turns.isEmpty) return null;
    final texts = [
      for (final (_, buffer) in turns) buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
    ];
    final order = <String, String>{};
    for (final (speaker, _) in turns) {
      order.putIfAbsent(speaker, () => _label(order.length));
    }
    if (order.length == 1) return texts.join(' ');
    return [for (var i = 0; i < turns.length; i++) '${order[turns[i].$1]}: ${texts[i]}']
        .join('\n\n');
  }

  /// A, B, … Z, then S27, S28 — more than 26 speakers is theoretical, but must not crash.
  static String _label(int index) =>
      index < 26 ? String.fromCharCode(0x41 + index) : 'S${index + 1}';
}
