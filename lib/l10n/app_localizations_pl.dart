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
  String get detailShareTooltip => 'Udostępnij';

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
  String get detailAddTagChip => 'tag';

  @override
  String get detailAddTagTitle => 'Dodaj tag';

  @override
  String get detailAddTagLabel => 'Nazwa tagu';

  @override
  String get detailAddTagDuplicate => 'Ten tag jest już przypisany.';

  @override
  String get detailAddTagConfirm => 'Dodaj';

  @override
  String get detailTagSaveError => 'Nie udało się zapisać zmiany tagów.';

  @override
  String get detailRemoveTagTooltip => 'Usuń tag';

  @override
  String get detailRetryProcessing => 'Ponów przetwarzanie';

  @override
  String get detailShareTranscript => 'Transkrypt';

  @override
  String get detailShareAudio => 'Plik audio';

  @override
  String get detailCopiedAudioPath =>
      'Skopiowano ścieżkę pliku audio do schowka.';

  @override
  String get detailShareError => 'Nie udało się udostępnić.';

  @override
  String get detailRegenerateTooltip => 'Wygeneruj ponownie';

  @override
  String get detailRegenerateTitle => 'Wygenerować ponownie?';

  @override
  String get detailRegenerateMessage =>
      'Transkrypt, tytuł i wszystkie tagi (także dodane ręcznie) zostaną usunięte, a nagranie przetworzone od nowa.';

  @override
  String get detailRegenerateConfirm => 'Regeneruj';

  @override
  String get detailRegenerateBusy => 'To nagranie jest właśnie przetwarzane.';

  @override
  String get detailRegenerateError => 'Nie udało się zresetować nagrania.';

  @override
  String get detailRewindTooltip => 'Cofnij o 10 sekund';

  @override
  String get detailForwardTooltip => 'Przewiń o 10 sekund';

  @override
  String get detailSpeedTooltip => 'Prędkość odtwarzania';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Pasek odtwarzania';

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
      'Brak konfiguracji API — uzupełnij adres i klucz w odpowiedniej sekcji Ustawień (transkrypcja, tagi lub notatki).';

  @override
  String get pipelineErrorSizeLimit =>
      'Nagranie jest za duże dla wybranego dostawcy transkrypcji (OpenAI i Groq: 25 MB, Gemini: 14 MB). Wybierz innego dostawcę, np. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Nieoczekiwany błąd: $detail';
  }

  @override
  String get errorUnknown => 'Nieznany błąd';

  @override
  String get navNotes => 'Notatki';

  @override
  String get notesTitle => 'Notatki';

  @override
  String get notesSearchHint => 'Szukaj w notatkach';

  @override
  String get notesEmpty =>
      'Brak notatek. Otwórz nagranie i użyj „Zrób notatkę”.';

  @override
  String get notesNoResults => 'Brak notatek pasujących do wyszukiwania.';

  @override
  String get noteUntitled => 'Notatka bez tytułu';

  @override
  String get noteTitleHint => 'Tytuł';

  @override
  String get noteContentHint => 'Treść notatki (Markdown)';

  @override
  String get noteEditTooltip => 'Edytuj';

  @override
  String get notePreviewTooltip => 'Podgląd';

  @override
  String noteSourceLink(String title) {
    return 'Źródło: $title';
  }

  @override
  String get noteSourceDeleted => 'Nagranie źródłowe zostało usunięte';

  @override
  String get noteDeleteTitle => 'Usunąć notatkę?';

  @override
  String get noteDeleteMessage =>
      'Notatka zostanie trwale usunięta. Nagranie i transkrypt zostają.';

  @override
  String get noteRegenerateTooltip => 'Wygeneruj ponownie z transkryptu';

  @override
  String get noteRegenerateTitle => 'Wygenerować notatkę od nowa?';

  @override
  String get noteRegenerateMessage =>
      'Treść i tytuł zostaną zastąpione nową wersją z aktualnego transkryptu. Twoje zmiany przepadną.';

  @override
  String get noteSaveError => 'Nie udało się zapisać notatki.';

  @override
  String get noteDeleted => 'Notatka usunięta.';

  @override
  String get detailMakeNote => 'Zrób notatkę';

  @override
  String get detailOpenNote => 'Otwórz notatkę';

  @override
  String get detailNoteGenerating => 'Tworzę notatkę…';

  @override
  String get detailTranscriptHint => 'Transkrypt jest pusty';

  @override
  String get detailTranscriptSaveError => 'Nie udało się zapisać transkryptu.';

  @override
  String get settingsSttModelHelp =>
      'Rozmówców rozpoznają ElevenLabs, Gemini i gpt-4o-transcribe-diarize (OpenAI). Whisper (Groq, OpenAI) nie rozróżnia mówców.';

  @override
  String get settingsSttSection => 'TRANSKRYPCJA';

  @override
  String get settingsTagsSection => 'TYTUŁY I TAGI';

  @override
  String get settingsNotesSection => 'NOTATKI';

  @override
  String get settingsModel => 'Model';

  @override
  String get translateTooltip => 'Przetłumacz';

  @override
  String get translatePickTitle => 'Przetłumacz na';

  @override
  String get translationOriginal => 'Oryginał';

  @override
  String get translationDeleteTooltip => 'Usuń tłumaczenie';

  @override
  String tagColorTitle(String tag) {
    return 'Kolor tagu „$tag”';
  }

  @override
  String get tagColorDefault => 'Domyślny';

  @override
  String get noteColorTitle => 'Kolor notatki';

  @override
  String get noteColorTooltip => 'Kolor';

  @override
  String get settingsTranslateSection => 'TŁUMACZENIE';

  @override
  String get settingsSampling => 'Steruj temperaturą i top_p';

  @override
  String get settingsSamplingHelp =>
      'Nie każdy model to obsługuje. Modele rozumujące (np. OpenAI GPT-5) odrzucają to błędem HTTP 400 — przy nich zostaw wyłączone.';

  @override
  String get settingsTemperature => 'Temperatura';

  @override
  String get settingsApiKeyInheritHelp =>
      'Puste — użyj klucza z Transkrypcji, jeśli adres jest ten sam.';

  @override
  String get settingsNoteStyle => 'Styl notatek';

  @override
  String get settingsNoteStyleDetailed => 'Szczegółowa';

  @override
  String get settingsNoteStyleDetailedHelp =>
      'Nagłówki, punkty i pogrubienia; zachowuje wszystkie istotne fakty, zadania jako checklista.';

  @override
  String get settingsNoteStyleConcise => 'Zwięzła';

  @override
  String get settingsNoteStyleConciseHelp =>
      'Kilka punktów z esencją i ewentualne zadania — do przeczytania w minutę.';

  @override
  String get settingsNoteStyleMeeting => 'Protokół spotkania';

  @override
  String get settingsNoteStyleMeetingHelp =>
      'Uczestnicy, tematy, decyzje, zadania (kto, co, do kiedy) i otwarte pytania.';

  @override
  String get settingsNoteStyleCasual => 'Luźna';

  @override
  String get settingsNoteStyleCasualHelp =>
      'Na luzie, przyjaźnie, z kilkoma emoji tam, gdzie pasują — bez zasypywania nimi tekstu.';

  @override
  String get settingsNoteStyleCustom => 'Własna';

  @override
  String get settingsNoteStyleCustomLabel => 'Instrukcje dla AI';

  @override
  String get settingsNoteStyleCustomHint =>
      'np. Pisz jak notatki do nauki: definicje, przykłady, na końcu 3 pytania kontrolne.';

  @override
  String get settingsNoteStyleCustomHelp =>
      'Format (Markdown, tytuł, język transkryptu) aplikacja pilnuje sama — tu opisz tylko styl i strukturę.';
}
