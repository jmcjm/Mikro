/// Target language offered for translations. [code] is what the database stores, [englishName]
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

  /// Language for a stored [code]; an unknown code (a newer version's language after a
  /// downgrade) still gets a usable entry named by the code itself.
  static TranslationLanguage of(String code) => all.firstWhere(
        (l) => l.code == code,
        orElse: () => TranslationLanguage(code, code, code),
      );
}
