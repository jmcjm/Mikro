import 'package:flutter/material.dart';
import 'package:mikro/l10n/app_localizations.dart';
import 'package:mikro/l10n/app_localizations_pl.dart';

/// Polskie teksty prosto z ARB. Testy porownuja z nimi zamiast z wklejonymi literalami:
/// poprawka copy w ARB nie ma zrywac testu, ktory sprawdza podpiecie klucza, a nie jego tresc.
final AppLocalizations plL10n = AppLocalizationsPl();

/// MaterialApp z delegatami l10n, przypiety na polski.
///
/// Delegaty sa obowiazkowe: bez nich `AppLocalizations.of()` rzuca przy pierwszym widgecie
/// z tekstem. Locale pinujemy, bo domyslnym locale testu jest en_US — bez tego kazdy test
/// sprawdzalby tlumaczenie zamiast jezyka zrodlowego.
Widget localizedApp(
  Widget home, {
  ThemeData? theme,
  Locale locale = const Locale('pl'),
  List<NavigatorObserver> navigatorObservers = const [],
}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      navigatorObservers: navigatorObservers,
      home: home,
    );
