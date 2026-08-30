import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

class TaggingApi {
  TaggingApi(this._dio);

  final Dio _dio;

  static const _maxTranscriptChars = 8000;
  static const _systemPrompt =
      'Generujesz tagi do transkrypcji nagrania glosowego. Zwroc WYLACZNIE '
      'tablice JSON zawierajaca 3-6 krotkich tagow (1-3 slowa kazdy), malymi '
      'literami, w jezyku transkrypcji. Zadnego innego tekstu.';

  Future<List<String>> generateTags(
      {required String transcript, required ProviderConfig config}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final content = await _chat(transcript, config);
      final tags = parseTags(content);
      if (tags != null) return tags;
    }
    throw MikroApiException(ApiErrorKind.badResponse, 'Model nie zwrócił poprawnych tagów.');
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
        throw MikroApiException(ApiErrorKind.badResponse, 'Nieoczekiwany format odpowiedzi API.');
      }
      final content = _extractContent(data);
      if (content is! String) {
        throw MikroApiException(ApiErrorKind.badResponse, 'Odpowiedź API bez treści wiadomości.');
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
      final tags = decoded
          .whereType<String>()
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet()
          .take(6)
          .toList();
      return tags.isEmpty ? null : tags;
    } on FormatException {
      return null;
    }
  }
}
