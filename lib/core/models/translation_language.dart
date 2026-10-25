/// Language offered as a translation target and as the language of a recording for
/// transcription. [code] (ISO 639-1) is what the database and settings store, [englishName]
/// goes into the prompt (models follow an English language name more reliably than a code),
/// [nativeName] is what the user sees — a language is recognisable in its own name whatever the
/// app's locale, so the list needs no localisation.
class TranslationLanguage {
  const TranslationLanguage(this.code, this.englishName, this.nativeName);

  final String code;
  final String englishName;
  final String nativeName;

  static const all = [
    TranslationLanguage('en', 'English', 'English'),
    TranslationLanguage('pl', 'Polish', 'Polski'),
    TranslationLanguage('de', 'German', 'Deutsch'),
    TranslationLanguage('fr', 'French', 'Français'),
    TranslationLanguage('es', 'Spanish', 'Español'),
    TranslationLanguage('it', 'Italian', 'Italiano'),
    TranslationLanguage('pt', 'Portuguese', 'Português'),
    TranslationLanguage('nl', 'Dutch', 'Nederlands'),
    TranslationLanguage('cs', 'Czech', 'Čeština'),
    TranslationLanguage('sk', 'Slovak', 'Slovenčina'),
    TranslationLanguage('uk', 'Ukrainian', 'Українська'),
    TranslationLanguage('ru', 'Russian', 'Русский'),
    TranslationLanguage('sv', 'Swedish', 'Svenska'),
    TranslationLanguage('no', 'Norwegian', 'Norsk'),
    TranslationLanguage('da', 'Danish', 'Dansk'),
    TranslationLanguage('fi', 'Finnish', 'Suomi'),
    TranslationLanguage('hu', 'Hungarian', 'Magyar'),
    TranslationLanguage('ro', 'Romanian', 'Română'),
    TranslationLanguage('tr', 'Turkish', 'Türkçe'),
    TranslationLanguage('ja', 'Japanese', '日本語'),
    TranslationLanguage('zh', 'Chinese (Simplified)', '中文'),
    TranslationLanguage('ko', 'Korean', '한국어'),
  ];

  /// Whether [code] looks like an ISO 639-1 or 639-3 code (`ka`, `yue`) — what the language
  /// field of the transcription APIs takes. Expects a normalised (trimmed, lower-case) value.
  static bool isValidCode(String code) => RegExp(r'^[a-z]{2,3}$').hasMatch(code);

  /// Language for a stored [code]; an unknown code (a newer version's language after a
  /// downgrade) still gets a usable entry named by the code itself.
  static TranslationLanguage of(String code) => all.firstWhere(
        (l) => l.code == code,
        orElse: () => TranslationLanguage(code, code, code),
      );
}
