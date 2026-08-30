// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get navRecord => 'Nagrywaj';

  @override
  String get navLibrary => 'Biblioteka';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get navAppearance => 'Wygląd';

  @override
  String get recorderHistoryTooltip => 'Biblioteka';

  @override
  String get recorderSavedSnackbar =>
      'Nagranie zapisane — transkrypcja w toku.';

  @override
  String get recorderSavedAction => 'Pokaż';

  @override
  String get recorderStatusRecording => 'Nagrywanie';

  @override
  String get recorderStatusReady => 'Gotowy do nagrywania';

  @override
  String get recorderErrorMicPermission => 'Brak uprawnień do mikrofonu.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Nie udało się uruchomić nagrywania: $detail';
  }

  @override
  String get libraryTitle => 'Biblioteka';

  @override
  String get librarySearchHint => 'Szukaj w transkrypcjach i tagach';

  @override
  String get libraryFilterAll => 'Wszystkie';

  @override
  String libraryDatabaseError(String detail) {
    return 'Błąd bazy: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Nic nie znaleziono.';

  @override
  String get libraryEmptyNoRecordings => 'Brak nagrań';

  @override
  String get libraryEmptyDescription =>
      'Wciśnij mikrofon na ekranie Nagrywaj — pierwsza notatka pojawi się tutaj z tagami.';

  @override
  String get libraryRecordCta => 'Nagraj pierwszą notatkę';

  @override
  String get libraryRetry => 'Ponów';

  @override
  String get detailTitle => 'Nagranie';

  @override
  String get detailBackTooltip => 'Wstecz';

  @override
  String get detailShareTooltip => 'Udostępnij transkrypt';

  @override
  String get detailCopyTooltip => 'Kopiuj transkrypt';

  @override
  String get detailDeleteTooltip => 'Usuń';

  @override
  String get detailDeleteTitle => 'Usunąć nagranie?';

  @override
  String get detailDeleteMessage =>
      'Plik audio i transkrypt zostaną trwale usunięte.';

  @override
  String get detailCancel => 'Anuluj';

  @override
  String get detailDelete => 'Usuń';

  @override
  String get detailDeleteError => 'Nie udało się usunąć nagrania.';

  @override
  String get detailRecordingDeleted => 'Nagranie usunięte.';

  @override
  String get detailCopiedTranscript => 'Skopiowano transkrypt do schowka.';

  @override
  String get detailCopied => 'Skopiowano.';

  @override
  String get detailTranscriptLabel => 'TRANSKRYPCJA';

  @override
  String get detailRetryProcessing => 'Ponów przetwarzanie';

  @override
  String get statusQueued => 'W kolejce…';

  @override
  String get statusTranscribing => 'Transkrypcja…';

  @override
  String get statusTagging => 'Tagowanie…';

  @override
  String get statusDone => 'Gotowe';

  @override
  String get statusError => 'Błąd';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsProviderSection => 'PROVIDER';

  @override
  String get settingsThemeSection => 'MOTYW';

  @override
  String get settingsProviderCustom => 'Własny';

  @override
  String get settingsBaseUrl => 'Base URL';

  @override
  String get settingsApiKey => 'Klucz API';

  @override
  String get settingsShowKey => 'Pokaż klucz';

  @override
  String get settingsHideKey => 'Ukryj klucz';

  @override
  String get settingsKeyStorage =>
      'Trzymany w keystore systemu, nie w SharedPreferences';

  @override
  String get settingsSttModel => 'Model STT';

  @override
  String get settingsTagModel => 'Model tagowania';

  @override
  String get settingsSave => 'Zapisz';

  @override
  String get settingsSaved => 'Ustawienia zapisane.';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsThemeSystem => 'Systemowy';

  @override
  String get onboardingWelcomeHeadline => 'Mów.\nMikro zapisze\ni otaguje.';

  @override
  String get onboardingWelcomeBody =>
      'Nagrania trafiają na Twoje urządzenie, transkrypcja i tagi lecą do wybranego providera.';

  @override
  String get onboardingMicHeadline => 'Najpierw\nmikrofon.';

  @override
  String get onboardingMicBody =>
      'System zapyta o zgodę raz. Bez niej Mikro nie nagra ani słowa.';

  @override
  String get onboardingMicTitle => 'Dostęp do mikrofonu';

  @override
  String get onboardingMicSubtitle => 'Wymagany do nagrywania';

  @override
  String get onboardingMicGranted => 'Przyznany';

  @override
  String get onboardingMicAllow => 'Zezwól';

  @override
  String get onboardingMicRetry => 'Ponów';

  @override
  String get onboardingMicDenied =>
      'Odmówiono. Dostęp włączysz w ustawieniach systemu.';

  @override
  String get onboardingProviderHeadline => 'Klucz API\ndodasz\nkiedy chcesz.';

  @override
  String get onboardingProviderBody =>
      'Transkrypcja i tagi lecą do Groqa albo OpenAI. Samo nagrywanie działa bez klucza.';

  @override
  String get onboardingProviderTitle => 'Klucz API';

  @override
  String get onboardingProviderSubtitle =>
      'Groq lub OpenAI — możesz dodać później';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingStart => 'Zaczynamy';

  @override
  String get apiErrorNetwork => 'Brak połączenia z siecią.';

  @override
  String get apiErrorAuth =>
      'Błąd autoryzacji — sprawdź klucz API w Ustawieniach.';

  @override
  String get apiErrorTooLarge => 'Plik odrzucony przez API — za duży.';

  @override
  String get apiErrorRateLimit =>
      'Limit zapytań przekroczony — spróbuj za chwilę.';

  @override
  String apiErrorServer(String detail) {
    return 'Błąd serwera dostawcy ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Nieoczekiwana odpowiedź serwera ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Nieoczekiwany format odpowiedzi API.';

  @override
  String get apiErrorNoContent => 'Odpowiedź API bez treści wiadomości.';

  @override
  String get apiErrorNoTranscript => 'Odpowiedź API bez pola text.';

  @override
  String get apiErrorBadTags => 'Model nie zwrócił poprawnych tagów.';

  @override
  String get pipelineErrorNoConfig =>
      'Brak konfiguracji API — ustaw klucz w Ustawieniach.';

  @override
  String get pipelineErrorSizeLimit =>
      'Nagranie przekracza limit 25 MB — za długie do transkrypcji.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Nieoczekiwany błąd: $detail';
  }

  @override
  String get errorUnknown => 'Nieznany błąd';
}
