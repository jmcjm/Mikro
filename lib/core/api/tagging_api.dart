import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

class TaggingApi {
  TaggingApi(this._dio);

  final Dio _dio;

  static const _maxTranscriptChars = 8000;

  /// Gorny limit tagow na nagranie. Jedno zrodlo prawdy: ta sama liczba idzie do promptu
  /// i tnie wynik po sparsowaniu.
  static const maxTags = 5;

  // Prompt po angielsku celowo. Instrukcja po polsku ciagnela model do polskich tagow
  // niezaleznie od jezyka nagrania, a aplikacja idzie w l10n — jezyk tagow ma isc
  // za transkryptem, nie za jezykiem instrukcji.
  static const _systemPrompt =
      'You label a transcript of a voice note. Return ONLY a JSON array of at '
      'most $maxTags short tags (1-3 words each), lowercase, written in the '
      'same language as the transcript. Tag only what the recording is '
      'specifically about: concrete topics, proper names, projects, people, '
      'places, events, technical terms. Never return generic labels that would '
      'fit any recording whatsoever, such as "note", "recording", '
      '"conversation", "audio", "voice", "thoughts", or their equivalents in '
      'the language of the transcript. Fewer sharp tags beat filling the '
      'limit; return [] when the transcript contains nothing specific. '
      'No other text.';

  Future<List<String>> generateTags(
      {required String transcript, required ProviderConfig config}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final content = await _chat(transcript, config);
      final tags = parseTags(content);
      if (tags != null) return tags;
    }
    throw MikroApiException(ApiErrorKind.badTags, 'tag list unparsable');
  }

  Future<String> _chat(String transcript, ProviderConfig config) async {
    final clipped = transcript.length > _maxTranscriptChars
        ? transcript.substring(0, _maxTranscriptChars)
        : transcript;
    try {
      final response = await _dio.post<dynamic>(
        '${config.baseUrl}/chat/completions',
        data: {
          'model': config.tagModel,
          'temperature': 0,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': clipped},
          ],
        },
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
      );
      // Rzutowanie i schodzenie po strukturze robimy sami, krok po kroku. Lancuch
      // data?['choices']?[0]?['message']?['content'] wypuszczal surowe bledy czasu wykonania:
      // RangeError przy pustej liscie choices i _TypeError przy kazdym innym ksztalcie,
      // a generyk post<Map<String, dynamic>> zamienial nie-mapowe cialo w falszywy blad sieci.
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw MikroApiException(ApiErrorKind.badFormat, 'response body is not an object');
      }
      final content = _extractContent(data);
      if (content is! String) {
        throw MikroApiException(ApiErrorKind.noContent, 'no message content in response');
      }
      return content;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Schodzi po `choices[0].message.content` bez zakladania czegokolwiek o ksztalcie
  /// odpowiedzi. Zwraca null dla kazdej struktury niezgodnej z kontraktem.
  static Object? _extractContent(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final choice = choices.first;
    if (choice is! Map) return null;
    final message = choice['message'];
    if (message is! Map) return null;
    return message['content'];
  }

  /// Limit [maxTags] egzekwujemy tutaj, nie tylko w prompcie: prompt to prosba, ktora model
  /// potrafi zignorowac, a pipeline zapisuje do bazy wszystko, co dostanie.
  static List<String>? parseTags(String content) {
    var s = content.trim();
    final fence = RegExp(r'^```[a-z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(s.substring(start, end + 1));
      if (decoded is! List) return null;
      // Puste [] to swiadoma odpowiedz "nie ma tu nic konkretnego" i leci dalej bez ponawiania.
      // Lista, ktora dopiero po odsianiu smieci robi sie pusta, to zepsuty output modelu — null,
      // czyli druga proba. Te dwie sciezki nie moga sie skleic.
      if (decoded.isEmpty) return const [];
      final tags = decoded
          .whereType<String>()
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet()
          .take(maxTags)
          .toList();
      return tags.isEmpty ? null : tags;
    } on FormatException {
      return null;
    }
  }
}
