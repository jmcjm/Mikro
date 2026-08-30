import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// Etykieta zakladki nagrywania w dolnym pasku i w railu.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywaj'**
  String get navRecord;

  /// Etykieta zakladki biblioteki w dolnym pasku i w railu.
  ///
  /// In pl, this message translates to:
  /// **'Biblioteka'**
  String get navLibrary;

  /// Etykieta zakladki ustawien w dolnym pasku i w railu.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia'**
  String get navSettings;

  /// Podpowiedz przycisku palety na dole railu; prowadzi do wyboru motywu w ustawieniach.
  ///
  /// In pl, this message translates to:
  /// **'Wygląd'**
  String get navAppearance;

  /// Podpowiedz ikony historii w pasku ekranu nagrywania.
  ///
  /// In pl, this message translates to:
  /// **'Biblioteka'**
  String get recorderHistoryTooltip;

  /// Pasek powiadomienia po zatrzymaniu nagrywania.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie zapisane — transkrypcja w toku.'**
  String get recorderSavedSnackbar;

  /// Akcja paska powiadomienia po zapisaniu nagrania; przenosi do biblioteki.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż'**
  String get recorderSavedAction;

  /// Pigulka stanu nad licznikiem, gdy nagrywanie trwa.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie'**
  String get recorderStatusRecording;

  /// Pigulka stanu nad licznikiem, gdy nagrywanie nie trwa.
  ///
  /// In pl, this message translates to:
  /// **'Gotowy do nagrywania'**
  String get recorderStatusReady;

  /// Karta bledu na ekranie nagrywania: system nie dal dostepu do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'Brak uprawnień do mikrofonu.'**
  String get recorderErrorMicPermission;

  /// Karta bledu na ekranie nagrywania: sterownik nagrywania odmowil startu.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się uruchomić nagrywania: {detail}'**
  String recorderErrorStartFailed(String detail);

  /// Naglowek ekranu biblioteki.
  ///
  /// In pl, this message translates to:
  /// **'Biblioteka'**
  String get libraryTitle;

  /// Podpowiedz w pustym polu wyszukiwania biblioteki.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w transkrypcjach i tagach'**
  String get librarySearchHint;

  /// Pierwszy chip filtru tagow: brak filtrowania.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie'**
  String get libraryFilterAll;

  /// Banner na liscie, gdy strumien bazy danych sie wywroci.
  ///
  /// In pl, this message translates to:
  /// **'Błąd bazy: {detail}'**
  String libraryDatabaseError(String detail);

  /// Stan pusty biblioteki, gdy dziala filtr albo szukanie.
  ///
  /// In pl, this message translates to:
  /// **'Nic nie znaleziono.'**
  String get libraryEmptyNoResults;

  /// Stan pusty biblioteki, gdy nie ma jeszcze zadnego nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Brak nagrań'**
  String get libraryEmptyNoRecordings;

  /// Objasnienie pod stanem pustym biblioteki.
  ///
  /// In pl, this message translates to:
  /// **'Wciśnij mikrofon na ekranie Nagrywaj — pierwsza notatka pojawi się tutaj z tagami.'**
  String get libraryEmptyDescription;

  /// Przycisk stanu pustego biblioteki; przelacza na ekran nagrywania.
  ///
  /// In pl, this message translates to:
  /// **'Nagraj pierwszą notatkę'**
  String get libraryRecordCta;

  /// Przycisk na karcie nagrania, ktore skonczylo sie bledem; wznawia przetwarzanie.
  ///
  /// In pl, this message translates to:
  /// **'Ponów'**
  String get libraryRetry;

  /// Tytul ekranu i naglowka panelu szczegolow nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie'**
  String get detailTitle;

  /// Podpowiedz strzalki powrotu w pasku szczegolow nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Wstecz'**
  String get detailBackTooltip;

  /// Podpowiedz ikony udostepniania w szczegolach nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij transkrypt'**
  String get detailShareTooltip;

  /// Podpowiedz ikony kopiowania w karcie transkryptu.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj transkrypt'**
  String get detailCopyTooltip;

  /// Podpowiedz ikony kosza w szczegolach nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get detailDeleteTooltip;

  /// Tytul okna potwierdzenia usuniecia nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć nagranie?'**
  String get detailDeleteTitle;

  /// Tresc okna potwierdzenia usuniecia nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Plik audio i transkrypt zostaną trwale usunięte.'**
  String get detailDeleteMessage;

  /// Przycisk odrzucenia w oknie potwierdzenia usuniecia.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get detailCancel;

  /// Przycisk potwierdzenia w oknie usuniecia nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get detailDelete;

  /// Pasek powiadomienia, gdy usuniecie nagrania z bazy sie nie powiodlo.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć nagrania.'**
  String get detailDeleteError;

  /// Tresc ekranu szczegolow, gdy nagranie zniknelo z bazy w trakcie ogladania.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie usunięte.'**
  String get detailRecordingDeleted;

  /// Pasek powiadomienia po kopiowaniu zamiast systemowego arkusza udostepniania.
  ///
  /// In pl, this message translates to:
  /// **'Skopiowano transkrypt do schowka.'**
  String get detailCopiedTranscript;

  /// Pasek powiadomienia po skopiowaniu transkryptu ikona kopiowania.
  ///
  /// In pl, this message translates to:
  /// **'Skopiowano.'**
  String get detailCopied;

  /// Naglowek karty transkryptu, wersalikami jak w makiecie.
  ///
  /// In pl, this message translates to:
  /// **'TRANSKRYPCJA'**
  String get detailTranscriptLabel;

  /// Etykieta kafelka z przerywana ramka w rzedzie tagow; przed nia stoi ikona plusa.
  ///
  /// In pl, this message translates to:
  /// **'tag'**
  String get detailAddTagChip;

  /// Tytul okna recznego dodawania tagu do nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj tag'**
  String get detailAddTagTitle;

  /// Etykieta pola tekstowego w oknie dodawania tagu.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa tagu'**
  String get detailAddTagLabel;

  /// Blad pod polem, gdy wpisany tag juz wisi przy tym nagraniu.
  ///
  /// In pl, this message translates to:
  /// **'Ten tag jest już przypisany.'**
  String get detailAddTagDuplicate;

  /// Przycisk zatwierdzenia w oknie dodawania tagu.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj'**
  String get detailAddTagConfirm;

  /// Pasek powiadomienia, gdy reczne dodanie albo usuniecie tagu nie doszlo do bazy.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać zmiany tagów.'**
  String get detailTagSaveError;

  /// Podpowiedz krzyzyka na chipie tagu w szczegolach nagrania.
  ///
  /// In pl, this message translates to:
  /// **'Usuń tag'**
  String get detailRemoveTagTooltip;

  /// Przycisk w bannerze bledu w szczegolach nagrania; wznawia przetwarzanie.
  ///
  /// In pl, this message translates to:
  /// **'Ponów przetwarzanie'**
  String get detailRetryProcessing;

  /// Odznaka statusu: nagranie czeka na transkrypcje.
  ///
  /// In pl, this message translates to:
  /// **'W kolejce…'**
  String get statusQueued;

  /// Odznaka statusu: trwa transkrypcja.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja…'**
  String get statusTranscribing;

  /// Odznaka statusu: trwa tagowanie transkryptu.
  ///
  /// In pl, this message translates to:
  /// **'Tagowanie…'**
  String get statusTagging;

  /// Odznaka statusu: przetwarzanie zakonczone.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe'**
  String get statusDone;

  /// Odznaka statusu: przetwarzanie skonczylo sie bledem.
  ///
  /// In pl, this message translates to:
  /// **'Błąd'**
  String get statusError;

  /// Naglowek ekranu ustawien.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia'**
  String get settingsTitle;

  /// Naglowek sekcji z wyborem dostawcy API; wersalikami jak w makiecie.
  ///
  /// In pl, this message translates to:
  /// **'PROVIDER'**
  String get settingsProviderSection;

  /// Naglowek sekcji z wyborem motywu; wersalikami jak w makiecie.
  ///
  /// In pl, this message translates to:
  /// **'MOTYW'**
  String get settingsThemeSection;

  /// Trzeci segment wyboru dostawcy: wlasny adres API. Groq i OpenAI to nazwy wlasne i zostaja nietlumaczone.
  ///
  /// In pl, this message translates to:
  /// **'Własny'**
  String get settingsProviderCustom;

  /// Etykieta pola z adresem bazowym API. Termin techniczny, ten sam w obu jezykach.
  ///
  /// In pl, this message translates to:
  /// **'Base URL'**
  String get settingsBaseUrl;

  /// Etykieta pola z kluczem API.
  ///
  /// In pl, this message translates to:
  /// **'Klucz API'**
  String get settingsApiKey;

  /// Podpowiedz ikony odslaniajacej klucz API.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż klucz'**
  String get settingsShowKey;

  /// Podpowiedz ikony ukrywajacej klucz API.
  ///
  /// In pl, this message translates to:
  /// **'Ukryj klucz'**
  String get settingsHideKey;

  /// Objasnienie pod polem klucza API. SharedPreferences to nazwa klasy i zostaje nietlumaczona.
  ///
  /// In pl, this message translates to:
  /// **'Trzymany w keystore systemu, nie w SharedPreferences'**
  String get settingsKeyStorage;

  /// Etykieta pola z nazwa modelu transkrypcji.
  ///
  /// In pl, this message translates to:
  /// **'Model STT'**
  String get settingsSttModel;

  /// Etykieta pola z nazwa modelu tagujacego.
  ///
  /// In pl, this message translates to:
  /// **'Model tagowania'**
  String get settingsTagModel;

  /// Przycisk zapisu ustawien.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get settingsSave;

  /// Pasek powiadomienia po zapisaniu ustawien.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia zapisane.'**
  String get settingsSaved;

  /// Karta motywu: jasny wariant palety domyslnej.
  ///
  /// In pl, this message translates to:
  /// **'Jasny'**
  String get settingsThemeLight;

  /// Karta motywu: ciemny wariant palety domyslnej.
  ///
  /// In pl, this message translates to:
  /// **'Ciemny'**
  String get settingsThemeDark;

  /// Karta motywu: jasnosc idzie za ustawieniem systemu. Dracula, Nord i Gruvbox to nazwy wlasne palet i zostaja nietlumaczone.
  ///
  /// In pl, this message translates to:
  /// **'Systemowy'**
  String get settingsThemeSystem;

  /// Naglowek pierwszego kroku wprowadzenia. Lamanie wierszy jest z makiety i ma zostac.
  ///
  /// In pl, this message translates to:
  /// **'Mów.\nMikro zapisze\ni otaguje.'**
  String get onboardingWelcomeHeadline;

  /// Tresc pierwszego kroku wprowadzenia.
  ///
  /// In pl, this message translates to:
  /// **'Nagrania trafiają na Twoje urządzenie, transkrypcja i tagi lecą do wybranego providera.'**
  String get onboardingWelcomeBody;

  /// Naglowek kroku z dostepem do mikrofonu. Lamanie wierszy jest z makiety.
  ///
  /// In pl, this message translates to:
  /// **'Najpierw\nmikrofon.'**
  String get onboardingMicHeadline;

  /// Tresc kroku z dostepem do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'System zapyta o zgodę raz. Bez niej Mikro nie nagra ani słowa.'**
  String get onboardingMicBody;

  /// Tytul karty z uprawnieniem do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'Dostęp do mikrofonu'**
  String get onboardingMicTitle;

  /// Podtytul karty z uprawnieniem do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'Wymagany do nagrywania'**
  String get onboardingMicSubtitle;

  /// Stan karty uprawnienia, gdy system dal dostep do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'Przyznany'**
  String get onboardingMicGranted;

  /// Przycisk proszacy system o dostep do mikrofonu.
  ///
  /// In pl, this message translates to:
  /// **'Zezwól'**
  String get onboardingMicAllow;

  /// Ten sam przycisk po odmowie: pyta jeszcze raz.
  ///
  /// In pl, this message translates to:
  /// **'Ponów'**
  String get onboardingMicRetry;

  /// Komunikat pod karta uprawnienia po odmowie dostepu.
  ///
  /// In pl, this message translates to:
  /// **'Odmówiono. Dostęp włączysz w ustawieniach systemu.'**
  String get onboardingMicDenied;

  /// Naglowek kroku z kluczem API. Lamanie wierszy jest z makiety.
  ///
  /// In pl, this message translates to:
  /// **'Klucz API\ndodasz\nkiedy chcesz.'**
  String get onboardingProviderHeadline;

  /// Tresc kroku z kluczem API.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja i tagi lecą do Groqa albo OpenAI. Samo nagrywanie działa bez klucza.'**
  String get onboardingProviderBody;

  /// Tytul karty prowadzacej do ustawien klucza.
  ///
  /// In pl, this message translates to:
  /// **'Klucz API'**
  String get onboardingProviderTitle;

  /// Podtytul karty prowadzacej do ustawien klucza.
  ///
  /// In pl, this message translates to:
  /// **'Groq lub OpenAI — możesz dodać później'**
  String get onboardingProviderSubtitle;

  /// Przycisk przejscia do nastepnego kroku wprowadzenia.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get onboardingNext;

  /// Ten sam przycisk na ostatnim kroku: konczy wprowadzenie.
  ///
  /// In pl, this message translates to:
  /// **'Zaczynamy'**
  String get onboardingStart;

  /// Blad przetwarzania: zapytanie nie doszlo do dostawcy.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z siecią.'**
  String get apiErrorNetwork;

  /// Blad przetwarzania: dostawca odrzucil klucz (HTTP 401 albo 403).
  ///
  /// In pl, this message translates to:
  /// **'Błąd autoryzacji — sprawdź klucz API w Ustawieniach.'**
  String get apiErrorAuth;

  /// Blad przetwarzania: dostawca odrzucil plik jako za duzy (HTTP 413).
  ///
  /// In pl, this message translates to:
  /// **'Plik odrzucony przez API — za duży.'**
  String get apiErrorTooLarge;

  /// Blad przetwarzania: dostawca odbil zapytanie limitem (HTTP 429).
  ///
  /// In pl, this message translates to:
  /// **'Limit zapytań przekroczony — spróbuj za chwilę.'**
  String get apiErrorRateLimit;

  /// Blad przetwarzania: dostawca odpowiedzial bledem 5xx.
  ///
  /// In pl, this message translates to:
  /// **'Błąd serwera dostawcy ({detail}).'**
  String apiErrorServer(String detail);

  /// Blad przetwarzania: odpowiedz dostawcy nie pasuje do kontraktu.
  ///
  /// In pl, this message translates to:
  /// **'Nieoczekiwana odpowiedź serwera ({detail}).'**
  String apiErrorBadResponse(String detail);

  /// Blad przetwarzania: cialo odpowiedzi dostawcy nie jest obiektem JSON.
  ///
  /// In pl, this message translates to:
  /// **'Nieoczekiwany format odpowiedzi API.'**
  String get apiErrorBadFormat;

  /// Blad przetwarzania: odpowiedz czatu nie niesie tresci wiadomosci.
  ///
  /// In pl, this message translates to:
  /// **'Odpowiedź API bez treści wiadomości.'**
  String get apiErrorNoContent;

  /// Blad przetwarzania: odpowiedz transkrypcji nie ma pola text.
  ///
  /// In pl, this message translates to:
  /// **'Odpowiedź API bez pola text.'**
  String get apiErrorNoTranscript;

  /// Blad przetwarzania: model dwa razy z rzedu oddal liste tagow nie do sparsowania.
  ///
  /// In pl, this message translates to:
  /// **'Model nie zwrócił poprawnych tagów.'**
  String get apiErrorBadTags;

  /// Blad przetwarzania: nagranie czeka, bo dostawca nie jest jeszcze skonfigurowany.
  ///
  /// In pl, this message translates to:
  /// **'Brak konfiguracji API — ustaw klucz w Ustawieniach.'**
  String get pipelineErrorNoConfig;

  /// Blad przetwarzania: plik audio jest wiekszy niz limit wysylki.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie przekracza limit 25 MB — za długie do transkrypcji.'**
  String get pipelineErrorSizeLimit;

  /// Blad przetwarzania spoza domeny API.
  ///
  /// In pl, this message translates to:
  /// **'Nieoczekiwany błąd: {detail}'**
  String pipelineErrorUnexpected(String detail);

  /// Ostatnia deska ratunku, gdy nagranie ma status bledu, ale baza nie zna jego rodzaju.
  ///
  /// In pl, this message translates to:
  /// **'Nieznany błąd'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
