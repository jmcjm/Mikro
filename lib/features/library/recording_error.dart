import '../../core/api/api_errors.dart';
import '../../core/pipeline/processing_pipeline.dart';
import '../../l10n/app_localizations.dart';

/// Sklada zdanie o awarii nagrania z tego, co lezy w bazie: rodzaju bledu i technicznego
/// szczegolu. Baza celowo nie trzyma gotowego komunikatu — nagranie moze wywalic sie przy
/// polskim interfejsie, a byc ogladane przy angielskim, wiec tekst powstaje przy rysowaniu,
/// a nie przy zapisie.
///
/// [kind] to `Recordings.errorKind`, czyli nazwa wartosci [ApiErrorKind] albo jedna ze stalych
/// `errorKind*` z pipeline'u. [detail] to `Recordings.errorMessage`: kod HTTP, opis wyjatku —
/// nigdy tekst dla uzytkownika, wiec wchodzi do zdania tylko tam, gdzie jest liczba albo
/// wyjatek bez znanego ksztaltu. Rodzaje opisujace konkretne zlamanie kontraktu maja wlasne
/// pelne zdania: angielska notka debugowa w srodku polskiego zdania to nie jest komunikat.
String recordingErrorText(AppLocalizations l10n, {String? kind, String? detail}) {
  final apiKind = ApiErrorKind.values.asNameMap()[kind];
  if (apiKind != null) {
    return switch (apiKind) {
      ApiErrorKind.network => l10n.apiErrorNetwork,
      ApiErrorKind.auth => l10n.apiErrorAuth,
      ApiErrorKind.tooLarge => l10n.apiErrorTooLarge,
      ApiErrorKind.rateLimit => l10n.apiErrorRateLimit,
      ApiErrorKind.server => l10n.apiErrorServer(detail ?? ''),
      ApiErrorKind.badResponse => l10n.apiErrorBadResponse(detail ?? ''),
      ApiErrorKind.badFormat => l10n.apiErrorBadFormat,
      ApiErrorKind.noContent => l10n.apiErrorNoContent,
      ApiErrorKind.noTranscript => l10n.apiErrorNoTranscript,
      ApiErrorKind.badTags => l10n.apiErrorBadTags,
    };
  }
  if (kind == errorKindNoConfig) return l10n.pipelineErrorNoConfig;
  if (kind == errorKindSizeLimit) return l10n.pipelineErrorSizeLimit;
  if (kind == errorKindUnknown && detail != null) return l10n.pipelineErrorUnexpected(detail);
  // Wiersze sprzed tej wersji maja errorKind NULL i cale zdanie w errorMessage. Pokazujemy je
  // takim, jakie jest: zamrozony jezyk to mniejsza strata niz zgubiony powod awarii.
  return detail ?? l10n.errorUnknown;
}
