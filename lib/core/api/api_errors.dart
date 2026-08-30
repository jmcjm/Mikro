import 'package:dio/dio.dart';

/// Rodzaj awarii rozmowy z dostawca. Kazda wartosc ma po drugiej stronie wlasne zdanie
/// w ARB — dlatego ksztalty odpowiedzi lamiace kontrakt maja osobne rodzaje, a nie jeden
/// worek z doklejanym opisem: opis bylby techniczna angielszczyzna wklejona w srodek
/// polskiego zdania.
///
/// Nazwy wartosci ida do kolumny `errorKind` i sa czescia formatu bazy.
enum ApiErrorKind {
  network,
  auth,
  tooLarge,
  rateLimit,
  server,

  /// Nieoczekiwany kod HTTP. Jedyny rodzaj z domeny API, ktory wciaga [MikroApiException.message]
  /// do zdania — bo tym szczegolem jest sam numer.
  badResponse,

  /// Cialo odpowiedzi nie jest obiektem JSON.
  badFormat,

  /// Odpowiedz czatu bez tresci wiadomosci: brak `choices`, pusta lista, zly ksztalt.
  noContent,

  /// Odpowiedz transkrypcji bez pola `text`.
  noTranscript,

  /// Model dwa razy z rzedu nie oddal listy tagow, ktora da sie sparsowac.
  badTags,
}

class MikroApiException implements Exception {
  MikroApiException(this.kind, this.message);

  final ApiErrorKind kind;

  /// Techniczny szczegol awarii: kod HTTP albo krotka notka o tym, czym odpowiedz zlamala
  /// kontrakt. NIE jest to tekst dla uzytkownika i celowo nie przechodzi przez l10n — warstwa
  /// sieciowa nie ma dostepu do BuildContextu, a komunikat i tak lezalby potem w bazie
  /// zamrozony w jezyku, ktory akurat obowiazywal przy zapisie. Zdanie dla uzytkownika sklada
  /// UI z samego [kind] (patrz `recordingErrorText`).
  ///
  /// Do zdania wchodzi jako `{detail}` tylko tam, gdzie szczegolem jest liczba:
  /// [ApiErrorKind.server] i [ApiErrorKind.badResponse]. Dla reszty zostaje sladem w logach
  /// i w bazie — nie ma po co wklejac angielskiej frazy debugowej w polskie zdanie.
  final String message;

  @override
  String toString() => 'MikroApiException($kind, $message)';
}

MikroApiException mapDioError(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401 || code == 403) return MikroApiException(ApiErrorKind.auth, 'HTTP $code');
  if (code == 413) return MikroApiException(ApiErrorKind.tooLarge, 'HTTP 413');
  if (code == 429) return MikroApiException(ApiErrorKind.rateLimit, 'HTTP 429');
  if (code != null && code >= 500) return MikroApiException(ApiErrorKind.server, 'HTTP $code');
  // Sam kod, bez cienia ciala odpowiedzi: pole wyladuje w bazie i na ekranie, a odpowiedzi
  // bledow potrafia odbijac echem to, co poszlo w zapytaniu.
  if (code != null) return MikroApiException(ApiErrorKind.badResponse, 'HTTP $code');
  return MikroApiException(ApiErrorKind.network, e.message ?? 'network error');
}
