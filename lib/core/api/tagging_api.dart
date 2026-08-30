import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import '../models/tag_name.dart';
import 'api_errors.dart';

/// Co model uklada o nagraniu w jednym przebiegu: krotki tytul i tagi.
///
/// Tytul jest polem miekkim — `null` znaczy "model nie oddal niczego, co da sie pokazac"
/// i jest calkowicie poprawnym wynikiem. UI ma na ten przypadek wlasny opad, a wymuszanie
/// tytulu ponowieniem kosztowaloby tagi, ktore model zwrocil poprawnie.
class RecordingMeta {
  const RecordingMeta({required this.title, required this.tags});

  final String? title;
  final List<String> tags;
}

class TaggingApi {
  TaggingApi(this._dio);

  final Dio _dio;

  static const _maxTranscriptChars = 8000;

  /// Gorny limit tagow na nagranie. Jedno zrodlo prawdy: ta sama liczba idzie do promptu
  /// i tnie wynik po sparsowaniu.
  static const maxTags = 5;

  /// Gorny limit dlugosci tytulu. Tak samo jak przy tagach: liczba idzie do promptu ORAZ
  /// tnie wynik, bo naglowek karty i panelu ma jedna linie, a nie akapit.
  static const maxTitleChars = 60;

  // Prompt po angielsku celowo. Instrukcja po polsku ciagnela model do polskich tagow
  // niezaleznie od jezyka nagrania, a aplikacja idzie w l10n — jezyk tytulu i tagow ma isc
  // za transkryptem, nie za jezykiem instrukcji.
  static const _systemPrompt =
      'You label a transcript of a voice note. Return ONLY a JSON object with '
      'exactly two keys: "title" and "tags", both written in the same language '
      'as the transcript. "title" is a short specific headline for this '
      'recording, at most $maxTitleChars characters, naming what the recording '
      'is actually about. "tags" is an array of at most $maxTags short tags '
      '(1-3 words each), lowercase. Tag only what the recording is '
      'specifically about: concrete topics, proper names, projects, people, '
      'places, events, technical terms. Never return generic labels or titles '
      'that would fit any recording whatsoever, such as "note", "recording", '
      '"conversation", "audio", "voice", "thoughts", or their equivalents in '
      'the language of the transcript. Fewer sharp tags beat filling the '
      'limit; return an empty array when the transcript contains nothing '
      'specific. No other text.';

  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final content = await _chat(transcript, config);
      final meta = parseMeta(content);
      if (meta != null) return meta;
    }
    throw MikroApiException(ApiErrorKind.badTags, 'meta object unparsable');
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

  /// Wyluskuje obiekt `{"title": ..., "tags": [...]}` z tego, co oddal model.
  ///
  /// `null` znaczy "ta odpowiedz nie nadaje sie do uzycia" i uruchamia ponowienie. Dotyczy to
  /// takze samej tablicy tagow — do schematu v4 byla poprawnym ksztaltem, teraz jest zepsutym
  /// outputem, bo po cichu gubilaby tytul.
  static RecordingMeta? parseMeta(String content) {
    var s = content.trim();
    final fence = RegExp(r'^```[a-z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(s.substring(start, end + 1));
      if (decoded is! Map) return null;
      final tags = _parseTags(decoded['tags']);
      if (tags == null) return null;
      return RecordingMeta(title: _parseTitle(decoded['title']), tags: tags);
    } on FormatException {
      return null;
    }
  }

  /// Limit [maxTags] egzekwujemy tutaj, nie tylko w prompcie: prompt to prosba, ktora model
  /// potrafi zignorowac, a pipeline zapisuje do bazy wszystko, co dostanie.
  static List<String>? _parseTags(Object? raw) {
    if (raw is! List) return null;
    // Puste [] to swiadoma odpowiedz "nie ma tu nic konkretnego" i leci dalej bez ponawiania.
    // Lista, ktora dopiero po odsianiu smieci robi sie pusta, to zepsuty output modelu — null,
    // czyli druga proba. Te dwie sciezki nie moga sie skleic.
    if (raw.isEmpty) return const [];
    final tags = raw
        .whereType<String>()
        .map(normalizeTagName)
        .where((t) => t.isNotEmpty)
        .toSet()
        .take(maxTags)
        .toList();
    return tags.isEmpty ? null : tags;
  }

  /// Tytul do jednej linii i do [maxTitleChars] znakow. Brak tytulu nie jest bledem, wiec
  /// kazdy ksztalt, ktorego nie da sie pokazac, konczy jako `null` — nie jako ponowienie.
  static String? _parseTitle(Object? raw) {
    if (raw is! String) return null;
    final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.isEmpty) return null;
    if (oneLine.length <= maxTitleChars) return oneLine;
    return oneLine.substring(0, maxTitleChars).trimRight();
  }
}
