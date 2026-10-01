// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get navRecord => 'Nahrávat';

  @override
  String get navLibrary => 'Knihovna';

  @override
  String get navSettings => 'Nastavení';

  @override
  String get navAppearance => 'Vzhled';

  @override
  String get recorderHistoryTooltip => 'Knihovna';

  @override
  String get recorderSavedSnackbar => 'Nahrávka uložena — probíhá přepis.';

  @override
  String get recorderSavedAction => 'Zobrazit';

  @override
  String get recorderStatusRecording => 'Nahrávání';

  @override
  String get recorderStatusReady => 'Připraveno k nahrávání';

  @override
  String get recorderErrorMicPermission => 'Chybí oprávnění k mikrofonu.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Nahrávání se nepodařilo spustit: $detail';
  }

  @override
  String get libraryTitle => 'Knihovna';

  @override
  String get librarySearchHint => 'Hledat v přepisech a štítcích';

  @override
  String get libraryFilterAll => 'Vše';

  @override
  String libraryDatabaseError(String detail) {
    return 'Chyba databáze: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Nic nenalezeno.';

  @override
  String get libraryEmptyNoRecordings => 'Žádné nahrávky';

  @override
  String get libraryEmptyDescription =>
      'Klepněte na mikrofon na obrazovce nahrávání — první poznámka se objeví tady, i se štítky.';

  @override
  String get libraryRecordCta => 'Nahrajte první poznámku';

  @override
  String get libraryRetry => 'Zkusit znovu';

  @override
  String get detailTitle => 'Nahrávka';

  @override
  String get detailBackTooltip => 'Zpět';

  @override
  String get detailShareTooltip => 'Sdílet';

  @override
  String get detailCopyTooltip => 'Kopírovat přepis';

  @override
  String get detailDeleteTooltip => 'Smazat';

  @override
  String get detailDeleteTitle => 'Smazat tuto nahrávku?';

  @override
  String get detailDeleteMessage =>
      'Zvukový soubor i přepis budou nenávratně smazány.';

  @override
  String get detailCancel => 'Zrušit';

  @override
  String get detailDelete => 'Smazat';

  @override
  String get detailDeleteError => 'Nahrávku se nepodařilo smazat.';

  @override
  String get detailRecordingDeleted => 'Nahrávka smazána.';

  @override
  String get detailCopiedTranscript => 'Přepis zkopírován do schránky.';

  @override
  String get detailCopied => 'Zkopírováno.';

  @override
  String get detailTranscriptLabel => 'PŘEPIS';

  @override
  String get detailAddTagChip => 'štítek';

  @override
  String get detailAddTagTitle => 'Přidat štítek';

  @override
  String get detailAddTagLabel => 'Název štítku';

  @override
  String get detailAddTagDuplicate => 'Tento štítek je již přiřazen.';

  @override
  String get detailAddTagConfirm => 'Přidat';

  @override
  String get detailTagSaveError => 'Změnu štítku se nepodařilo uložit.';

  @override
  String get detailRemoveTagTooltip => 'Odebrat štítek';

  @override
  String get detailRetryProcessing => 'Zopakovat zpracování';

  @override
  String get detailShareTranscript => 'Přepis';

  @override
  String get detailShareAudio => 'Zvukový soubor';

  @override
  String get detailCopiedAudioPath =>
      'Cesta ke zvukovému souboru zkopírována do schránky.';

  @override
  String get detailShareError => 'Sdílení se nezdařilo.';

  @override
  String get detailRegenerateTooltip => 'Vygenerovat znovu';

  @override
  String get detailRegenerateTitle => 'Vygenerovat znovu?';

  @override
  String get detailRegenerateMessage =>
      'Přepis, název i všechny štítky (včetně ručních) budou odstraněny a nahrávka se zpracuje od začátku.';

  @override
  String get detailRegenerateConfirm => 'Vygenerovat';

  @override
  String get detailRegenerateBusy => 'Tato nahrávka se právě zpracovává.';

  @override
  String get detailRegenerateError => 'Nahrávku se nepodařilo obnovit.';

  @override
  String get detailRewindTooltip => 'Zpět o 10 sekund';

  @override
  String get detailForwardTooltip => 'Vpřed o 10 sekund';

  @override
  String get detailSpeedTooltip => 'Rychlost přehrávání';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Lišta přehrávání';

  @override
  String get statusQueued => 'Ve frontě…';

  @override
  String get statusTranscribing => 'Přepisuji…';

  @override
  String get statusTagging => 'Přidávám štítky…';

  @override
  String get statusDone => 'Hotovo';

  @override
  String get statusError => 'Chyba';

  @override
  String get settingsTitle => 'Nastavení';

  @override
  String get settingsThemeSection => 'MOTIV';

  @override
  String get settingsProviderCustom => 'Vlastní';

  @override
  String get settingsBaseUrl => 'Základní URL';

  @override
  String get settingsApiKey => 'Klíč API';

  @override
  String get settingsShowKey => 'Zobrazit klíč';

  @override
  String get settingsHideKey => 'Skrýt klíč';

  @override
  String get settingsSave => 'Uložit';

  @override
  String get settingsSaved => 'Nastavení uloženo.';

  @override
  String get settingsThemeLight => 'Světlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get settingsThemeSystem => 'Systémový';

  @override
  String get onboardingWelcomeHeadline =>
      'Mluvte.\nMikro to zapíše\na označí štítky.';

  @override
  String get onboardingWelcomeBody =>
      'Nahrávky zůstávají ve vašem zařízení, přepis a štítky jdou k poskytovateli, kterého si vyberete.';

  @override
  String get onboardingMicHeadline => 'Nejdřív\nmikrofon.';

  @override
  String get onboardingMicBody =>
      'Systém se zeptá jen jednou. Bez přístupu Mikro nenahraje ani slovo.';

  @override
  String get onboardingMicTitle => 'Přístup k mikrofonu';

  @override
  String get onboardingMicSubtitle => 'Nutný pro nahrávání';

  @override
  String get onboardingMicGranted => 'Povoleno';

  @override
  String get onboardingMicAllow => 'Povolit';

  @override
  String get onboardingMicRetry => 'Zkusit znovu';

  @override
  String get onboardingMicDenied =>
      'Zamítnuto. Zapněte přístup v nastavení systému.';

  @override
  String get onboardingProviderHeadline =>
      'Klíč API\nmůže počkat,\njak dlouho chcete.';

  @override
  String get onboardingProviderBody =>
      'Přepis a štítky jdou ke Groq nebo OpenAI. Samotné nahrávání funguje bez klíče.';

  @override
  String get onboardingProviderTitle => 'Klíč API';

  @override
  String get onboardingProviderSubtitle =>
      'Groq nebo OpenAI — lze přidat později';

  @override
  String get onboardingNext => 'Další';

  @override
  String get onboardingStart => 'Jdeme na to';

  @override
  String get apiErrorNetwork => 'Žádné připojení k síti.';

  @override
  String get apiErrorAuth =>
      'Autorizace selhala — zkontrolujte klíč API v Nastavení.';

  @override
  String get apiErrorTooLarge => 'API soubor odmítlo — je příliš velký.';

  @override
  String get apiErrorRateLimit =>
      'Překročen limit požadavků — zkuste to za chvíli.';

  @override
  String apiErrorServer(String detail) {
    return 'Chyba serveru poskytovatele ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Neočekávaná odpověď serveru ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Neočekávaný formát odpovědi API.';

  @override
  String get apiErrorNoContent => 'Odpověď API neobsahovala text zprávy.';

  @override
  String get apiErrorNoTranscript => 'Odpověď API neobsahovala textové pole.';

  @override
  String get apiErrorBadTags => 'Model nevrátil žádné použitelné štítky.';

  @override
  String get pipelineErrorNoConfig =>
      'Chybí konfigurace API — vyplňte adresu a klíč v příslušné části Nastavení (přepis, štítky nebo poznámky).';

  @override
  String get pipelineErrorSizeLimit =>
      'Nahrávka je příliš velká pro vybraného poskytovatele přepisu (OpenAI a Groq: 25 MB, Gemini: 14 MB). Zvolte jiného poskytovatele, např. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Neočekávaná chyba: $detail';
  }

  @override
  String get errorUnknown => 'Neznámá chyba';

  @override
  String get navNotes => 'Poznámky';

  @override
  String get notesTitle => 'Poznámky';

  @override
  String get notesSearchHint => 'Hledat v poznámkách';

  @override
  String get notesEmpty =>
      'Zatím žádné poznámky. Otevřete nahrávku a použijte „Vytvořit poznámku“.';

  @override
  String get notesNoResults => 'Hledání neodpovídá žádná poznámka.';

  @override
  String get noteUntitled => 'Poznámka bez názvu';

  @override
  String get noteTitleHint => 'Název';

  @override
  String get noteContentHint => 'Obsah poznámky (Markdown)';

  @override
  String get noteEditTooltip => 'Upravit';

  @override
  String get notePreviewTooltip => 'Náhled';

  @override
  String get noteShareTooltip => 'Sdílet';

  @override
  String noteSourceLink(String title) {
    return 'Zdroj: $title';
  }

  @override
  String get noteSourceDeleted => 'Zdrojová nahrávka byla smazána';

  @override
  String get noteDeleteTitle => 'Smazat poznámku?';

  @override
  String get noteDeleteMessage =>
      'Poznámka bude nenávratně smazána. Nahrávka a přepis zůstanou.';

  @override
  String get noteRegenerateTooltip => 'Vygenerovat znovu z přepisu';

  @override
  String get noteRegenerateTitle => 'Vygenerovat poznámku znovu?';

  @override
  String get noteRegenerateMessage =>
      'Obsah a název budou nahrazeny novou verzí z aktuálního přepisu. Vaše úpravy budou ztraceny.';

  @override
  String get noteSaveError => 'Poznámku se nepodařilo uložit.';

  @override
  String get noteDeleted => 'Poznámka smazána.';

  @override
  String get detailMakeNote => 'Vytvořit poznámku';

  @override
  String get detailOpenNote => 'Otevřít poznámku';

  @override
  String get detailNoteGenerating => 'Vytvářím poznámku…';

  @override
  String get detailTranscriptHint => 'Přepis je prázdný';

  @override
  String get detailTranscriptSaveError => 'Přepis se nepodařilo uložit.';

  @override
  String get settingsSttModelHelp =>
      'Mluvčí rozpoznávají ElevenLabs, Gemini a gpt-4o-transcribe-diarize (OpenAI). Whisper (Groq, OpenAI) mluvčí nerozlišuje.';

  @override
  String get settingsModel => 'Model';

  @override
  String get navQuickRecord => 'Spustit nahrávání';

  @override
  String get navQuickRecordStop => 'Zastavit nahrávání';

  @override
  String get translateTooltip => 'Přeložit';

  @override
  String get translatePickTitle => 'Přeložit do';

  @override
  String get translationOriginal => 'Originál';

  @override
  String get translationDeleteTooltip => 'Smazat překlad';

  @override
  String tagColorTitle(String tag) {
    return 'Barva štítku „$tag“';
  }

  @override
  String get tagColorDefault => 'Výchozí';

  @override
  String get noteColorTitle => 'Barva poznámky';

  @override
  String get noteColorTooltip => 'Barva';

  @override
  String get settingsSampling => 'Řídit temperature a top_p';

  @override
  String get settingsSamplingHelp =>
      'Ne každý model to podporuje. Modely s uvažováním (např. OpenAI GPT-5) to odmítnou s HTTP 400 — u nich nechte vypnuto.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp =>
      'Nechte prázdné, aby se při stejné adrese použil klíč z Přepisu.';

  @override
  String get settingsNoteStyleDetailed => 'Podrobný';

  @override
  String get settingsNoteStyleDetailedHelp =>
      'Nadpisy, odrážky a tučné písmo; zachová každý podstatný fakt, úkoly jako kontrolní seznam.';

  @override
  String get settingsNoteStyleConcise => 'Stručný';

  @override
  String get settingsNoteStyleConciseHelp =>
      'Pár odrážek s tím nejdůležitějším a případnými úkoly — přečtete za minutu.';

  @override
  String get settingsNoteStyleMeeting => 'Zápis z porady';

  @override
  String get settingsNoteStyleMeetingHelp =>
      'Účastníci, témata, rozhodnutí, úkoly (kdo, co, do kdy) a otevřené otázky.';

  @override
  String get settingsNoteStyleCasual => 'Nezávazný';

  @override
  String get settingsNoteStyleCasualHelp =>
      'Uvolněný a přátelský, s pár dobře umístěnými emoji — ne jejich hromadou.';

  @override
  String get settingsNoteStyleCustom => 'Vlastní';

  @override
  String get settingsNoteStyleCustomLabel => 'Pokyny pro AI';

  @override
  String get settingsNoteStyleCustomHint =>
      'např. Piš studijní poznámky: definice, příklady a na konci 3 opakovací otázky.';

  @override
  String get settingsNoteStyleCustomHelp =>
      'Formát (Markdown, název, jazyk přepisu) určuje aplikace sama — popište zde jen styl a strukturu.';

  @override
  String get settingsServicesSection => 'SLUŽBY AI';

  @override
  String get settingsSttTitle => 'Přepis';

  @override
  String get settingsTagsTitle => 'Názvy a štítky';

  @override
  String get settingsNotesTitle => 'Poznámky';

  @override
  String get settingsTranslateTitle => 'Překlad';

  @override
  String get settingsProviderSection => 'POSKYTOVATEL';

  @override
  String get settingsNoteStyleSection => 'STYL POZNÁMKY';

  @override
  String get settingsApiKeyInheritHint => 'Z Přepisu';

  @override
  String get settingsAdvanced => 'Pokročilé';

  @override
  String get settingsAdvancedSamplingSummary =>
      'Základní URL · temperature a top_p';

  @override
  String get settingsBaseUrlFromProvider =>
      'Základní URL · určuje poskytovatel';

  @override
  String settingsAdvancedSamplingValues(String temperature, String topP) {
    return 'Základní URL · temperature $temperature, top_p $topP';
  }
}
