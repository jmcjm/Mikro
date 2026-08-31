import 'package:flutter/material.dart';
import 'package:mikro/l10n/app_localizations.dart';
import 'package:mikro/l10n/app_localizations_pl.dart';

/// Polish strings directly from ARB. Tests compare against them instead of hardcoded literals:
/// copy edits in ARB should not break tests checking key wiring rather than content.
final AppLocalizations plL10n = AppLocalizationsPl();

/// MaterialApp with l10n delegates pinned to Polish.
///
/// Delegates are required: without them `AppLocalizations.of()` throws on first text widget.
/// We pin the locale because the default test locale is en_US — without this each test
/// would check the translation instead of source language.
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
