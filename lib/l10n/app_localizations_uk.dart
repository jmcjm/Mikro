// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get navRecord => 'Запис';

  @override
  String get navLibrary => 'Бібліотека';

  @override
  String get navSettings => 'Налаштування';

  @override
  String get navAppearance => 'Вигляд';

  @override
  String get recorderHistoryTooltip => 'Бібліотека';

  @override
  String get recorderSavedSnackbar => 'Запис збережено — триває транскрибування.';

  @override
  String get recorderSavedAction => 'Показати';

  @override
  String get recorderStatusRecording => 'Триває запис';

  @override
  String get recorderStatusReady => 'Готово до запису';

  @override
  String get recorderErrorMicPermission => 'Немає дозволу на мікрофон.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Не вдалося почати запис: $detail';
  }

  @override
  String get libraryTitle => 'Бібліотека';

  @override
  String get librarySearchHint => 'Пошук у транскрипціях і тегах';

  @override
  String get libraryFilterAll => 'Усі';

  @override
  String libraryDatabaseError(String detail) {
    return 'Помилка бази даних: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Нічого не знайдено.';

  @override
  String get libraryEmptyNoRecordings => 'Немає записів';

  @override
  String get libraryEmptyDescription => 'Торкніться мікрофона на екрані запису — ваша перша нотатка з\'явиться тут із тегами.';

  @override
  String get libraryRecordCta => 'Запишіть першу нотатку';

  @override
  String get libraryRetry => 'Повторити';

  @override
  String get detailTitle => 'Запис';

  @override
  String get detailBackTooltip => 'Назад';

  @override
  String get detailShareTooltip => 'Поділитися';

  @override
  String get detailCopyTooltip => 'Копіювати транскрипцію';

  @override
  String get detailDeleteTooltip => 'Видалити';

  @override
  String get detailDeleteTitle => 'Видалити цей запис?';

  @override
  String get detailDeleteMessage => 'Аудіофайл і транскрипція будуть видалені назавжди.';

  @override
  String get detailCancel => 'Скасувати';

  @override
  String get detailDelete => 'Видалити';

  @override
  String get detailDeleteError => 'Не вдалося видалити запис.';

  @override
  String get detailRecordingDeleted => 'Запис видалено.';

  @override
  String get detailCopiedTranscript => 'Транскрипцію скопійовано в буфер обміну.';

  @override
  String get detailCopied => 'Скопійовано.';

  @override
  String get detailTranscriptLabel => 'ТРАНСКРИПЦІЯ';

  @override
  String get detailAddTagChip => 'тег';

  @override
  String get detailAddTagTitle => 'Додати тег';

  @override
  String get detailAddTagLabel => 'Назва тега';

  @override
  String get detailAddTagDuplicate => 'Цей тег уже призначено.';

  @override
  String get detailAddTagConfirm => 'Додати';

  @override
  String get detailTagSaveError => 'Не вдалося зберегти зміну тега.';

  @override
  String get detailRemoveTagTooltip => 'Видалити тег';

  @override
  String get detailRetryProcessing => 'Повторити обробку';

  @override
  String get detailShareTranscript => 'Транскрипція';

  @override
  String get detailShareAudio => 'Аудіофайл';

  @override
  String get detailCopiedAudioPath => 'Шлях до аудіофайлу скопійовано в буфер обміну.';

  @override
  String get detailShareError => 'Не вдалося поділитися.';

  @override
  String get detailRegenerateTooltip => 'Згенерувати заново';

  @override
  String get detailRegenerateTitle => 'Згенерувати заново?';

  @override
  String get detailRegenerateMessage => 'Транскрипцію, назву та всі теги (разом із доданими вручну) буде видалено, а запис обробиться з нуля.';

  @override
  String get detailRegenerateConfirm => 'Згенерувати';

  @override
  String get detailRegenerateBusy => 'Цей запис саме обробляється.';

  @override
  String get detailRegenerateError => 'Не вдалося скинути запис.';

  @override
  String get detailRewindTooltip => 'Назад на 10 секунд';

  @override
  String get detailForwardTooltip => 'Вперед на 10 секунд';

  @override
  String get detailSpeedTooltip => 'Швидкість відтворення';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Смуга відтворення';

  @override
  String get statusQueued => 'У черзі…';

  @override
  String get statusTranscribing => 'Транскрибування…';

  @override
  String get statusTagging => 'Додавання тегів…';

  @override
  String get statusDone => 'Готово';

  @override
  String get statusError => 'Помилка';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get settingsThemeSection => 'ТЕМА';

  @override
  String get settingsProviderCustom => 'Власний';

  @override
  String get settingsBaseUrl => 'Базова URL-адреса';

  @override
  String get settingsApiKey => 'Ключ API';

  @override
  String get settingsShowKey => 'Показати ключ';

  @override
  String get settingsHideKey => 'Сховати ключ';

  @override
  String get settingsSave => 'Зберегти';

  @override
  String get settingsSaved => 'Налаштування збережено.';

  @override
  String get settingsThemeLight => 'Світла';

  @override
  String get settingsThemeDark => 'Темна';

  @override
  String get settingsThemeSystem => 'Системна';

  @override
  String get onboardingWelcomeHeadline => 'Говоріть.\nMikro запише\nі додасть теги.';

  @override
  String get onboardingWelcomeBody => 'Записи залишаються на вашому пристрої, а транскрипція й теги надходять до обраного вами провайдера.';

  @override
  String get onboardingMicHeadline => 'Спершу\nмікрофон.';

  @override
  String get onboardingMicBody => 'Система запитує лише раз. Без доступу Mikro не запише жодного слова.';

  @override
  String get onboardingMicTitle => 'Доступ до мікрофона';

  @override
  String get onboardingMicSubtitle => 'Потрібен для запису';

  @override
  String get onboardingMicGranted => 'Надано';

  @override
  String get onboardingMicAllow => 'Дозволити';

  @override
  String get onboardingMicRetry => 'Повторити';

  @override
  String get onboardingMicDenied => 'Відхилено. Увімкніть доступ у налаштуваннях системи.';

  @override
  String get onboardingProviderHeadline => 'Ключ API\nможе зачекати,\nскільки завгодно.';

  @override
  String get onboardingProviderBody => 'Транскрипція й теги надходять до Groq або OpenAI. Сам запис працює без ключа.';

  @override
  String get onboardingProviderTitle => 'Ключ API';

  @override
  String get onboardingProviderSubtitle => 'Groq або OpenAI — можна додати пізніше';

  @override
  String get onboardingNext => 'Далі';

  @override
  String get onboardingStart => 'Починаймо';

  @override
  String get apiErrorNetwork => 'Немає з\'єднання з мережею.';

  @override
  String get apiErrorAuth => 'Помилка авторизації — перевірте ключ API в налаштуваннях.';

  @override
  String get apiErrorTooLarge => 'API відхилив файл — завеликий.';

  @override
  String get apiErrorRateLimit => 'Перевищено ліміт запитів — спробуйте за хвилину.';

  @override
  String apiErrorServer(String detail) {
    return 'Помилка сервера провайдера ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Несподівана відповідь сервера ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Несподіваний формат відповіді API.';

  @override
  String get apiErrorNoContent => 'Відповідь API не містила тексту повідомлення.';

  @override
  String get apiErrorNoTranscript => 'У відповіді API не було текстового поля.';

  @override
  String get apiErrorBadTags => 'Модель не повернула придатних тегів.';

  @override
  String get pipelineErrorNoConfig => 'Немає конфігурації API — заповніть адресу й ключ у відповідному розділі налаштувань (транскрипція, теги або нотатки).';

  @override
  String get pipelineErrorSizeLimit => 'Запис завеликий для обраного провайдера транскрипції (OpenAI і Groq: 25 МБ, Gemini: 14 МБ). Оберіть іншого провайдера, наприклад ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Несподівана помилка: $detail';
  }

  @override
  String get errorUnknown => 'Невідома помилка';

  @override
  String get navNotes => 'Нотатки';

  @override
  String get notesTitle => 'Нотатки';

  @override
  String get notesSearchHint => 'Пошук нотаток';

  @override
  String get notesEmpty => 'Нотаток ще немає. Відкрийте запис і скористайтеся «Створити нотатку».';

  @override
  String get notesNoResults => 'Жодна нотатка не відповідає пошуку.';

  @override
  String get noteUntitled => 'Нотатка без назви';

  @override
  String get noteTitleHint => 'Назва';

  @override
  String get noteContentHint => 'Зміст нотатки (Markdown)';

  @override
  String get noteEditTooltip => 'Редагувати';

  @override
  String get notePreviewTooltip => 'Попередній перегляд';

  @override
  String get noteShareTooltip => 'Поділитися';

  @override
  String noteSourceLink(String title) {
    return 'Джерело: $title';
  }

  @override
  String get noteSourceDeleted => 'Вихідний запис видалено';

  @override
  String get noteDeleteTitle => 'Видалити нотатку?';

  @override
  String get noteDeleteMessage => 'Нотатку буде видалено назавжди. Запис і транскрипція залишаться.';

  @override
  String get noteRegenerateTooltip => 'Згенерувати заново з транскрипції';

  @override
  String get noteRegenerateTitle => 'Згенерувати нотатку заново?';

  @override
  String get noteRegenerateMessage => 'Зміст і назву буде замінено новою версією з поточної транскрипції. Ваші правки буде втрачено.';

  @override
  String get noteSaveError => 'Не вдалося зберегти нотатку.';

  @override
  String get noteDeleted => 'Нотатку видалено.';

  @override
  String get detailMakeNote => 'Створити нотатку';

  @override
  String get detailOpenNote => 'Відкрити нотатку';

  @override
  String get detailNoteGenerating => 'Створення нотатки…';

  @override
  String get detailTranscriptHint => 'Транскрипція порожня';

  @override
  String get detailTranscriptSaveError => 'Не вдалося зберегти транскрипцію.';

  @override
  String get settingsSttModelHelp => 'Мовців розпізнають ElevenLabs, Gemini та gpt-4o-transcribe-diarize (OpenAI). Whisper (Groq, OpenAI) мовців не розрізняє.';

  @override
  String get settingsModel => 'Модель';

  @override
  String get navQuickRecord => 'Почати запис';

  @override
  String get navQuickRecordStop => 'Зупинити запис';

  @override
  String get translateTooltip => 'Перекласти';

  @override
  String get translatePickTitle => 'Перекласти мовою';

  @override
  String get translationOriginal => 'Оригінал';

  @override
  String get translationDeleteTooltip => 'Видалити переклад';

  @override
  String tagColorTitle(String tag) {
    return 'Колір «$tag»';
  }

  @override
  String get tagColorDefault => 'За замовчуванням';

  @override
  String get noteColorTitle => 'Колір нотатки';

  @override
  String get noteColorTooltip => 'Колір';

  @override
  String get settingsSampling => 'Керувати temperature і top_p';

  @override
  String get settingsSamplingHelp => 'Не кожна модель це підтримує. Моделі з міркуванням (наприклад, OpenAI GPT-5) відхиляють це з HTTP 400 — для них залиште вимкненим.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp => 'Залиште порожнім, щоб використати ключ Транскрипції, якщо адреса та сама.';

  @override
  String get settingsNoteStyleDetailed => 'Докладний';

  @override
  String get settingsNoteStyleDetailedHelp => 'Заголовки, марковані списки й жирний шрифт; зберігає кожен важливий факт, завдання — як чекліст.';

  @override
  String get settingsNoteStyleConcise => 'Стислий';

  @override
  String get settingsNoteStyleConciseHelp => 'Кілька пунктів із найважливішим і завданнями, якщо вони є — читається за хвилину.';

  @override
  String get settingsNoteStyleMeeting => 'Протокол зустрічі';

  @override
  String get settingsNoteStyleMeetingHelp => 'Учасники, теми, рішення, завдання (хто, що, до коли) і відкриті питання.';

  @override
  String get settingsNoteStyleCasual => 'Невимушений';

  @override
  String get settingsNoteStyleCasualHelp => 'Невимушено й дружньо, з кількома доречними емодзі — без їхнього надміру.';

  @override
  String get settingsNoteStyleCustom => 'Власний';

  @override
  String get settingsNoteStyleCustomLabel => 'Інструкції для ШІ';

  @override
  String get settingsNoteStyleCustomHint => 'наприклад: Пиши навчальні конспекти: визначення, приклади та 3 запитання для повторення наприкінці.';

  @override
  String get settingsNoteStyleCustomHelp => 'Формат (Markdown, назва, мова транскрипції) застосунок задає сам — тут опишіть лише стиль і структуру.';

  @override
  String get settingsServicesSection => 'СЕРВІСИ ШІ';

  @override
  String get settingsSttTitle => 'Транскрипція';

  @override
  String get settingsTagsTitle => 'Назви й теги';

  @override
  String get settingsNotesTitle => 'Нотатки';

  @override
  String get settingsTranslateTitle => 'Переклад';

  @override
  String get settingsProviderSection => 'ПРОВАЙДЕР';

  @override
  String get settingsNoteStyleSection => 'СТИЛЬ НОТАТКИ';

  @override
  String get settingsApiKeyInheritHint => 'З Транскрипції';

  @override
  String get settingsAdvanced => 'Додатково';

  @override
  String get settingsAdvancedSamplingSummary => 'Базова URL · temperature і top_p';

  @override
  String get settingsBaseUrlFromProvider => 'Базова URL · задає провайдер';

  @override
  String settingsAdvancedSamplingValues(String temperature, String topP) {
    return 'Базова URL · temperature $temperature, top_p $topP';
  }
