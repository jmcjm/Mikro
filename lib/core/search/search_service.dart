import 'dart:math';

import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../db/database.dart';

/// Zwijanie polskich znakow diakrytycznych do golego ASCII. fuzzywuzzy porownuje znaki
/// jeden do jednego, wiec dla algorytmu 's' i 's z kreska' to dwie zupelnie rozne litery:
/// zapytanie "sledz" o tekst "sledz z kreskami" dostawalo 22 punkty zamiast 100. User pisze
/// w polu wyszukiwania bez ogonkow (i transkrypt bywa bez nich), wiec obie strony sprowadzamy
/// do wspolnego mianownika. Wielkie litery zdejmuje wczesniej `toLowerCase`, wiec mapa
/// obsluguje tylko male.
const _diacriticFolding = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
};

/// Wszystko, co nie jest litera ani cyfra, rozdziela tokeny. Klasy unikodowe zamiast [a-z0-9],
/// zeby tekst w obcym alfabecie nie rozpadl sie na pojedyncze znaki.
final _tokenSeparator = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

String _normalize(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_diacriticFolding[char] ?? char);
  }
  return buffer.toString();
}

List<String> _tokenize(String normalized) =>
    normalized.split(_tokenSeparator).where((token) => token.isNotEmpty).toList();

/// Najlepsze dopasowanie pojedynczego tokenu zapytania do ktoregokolwiek tokenu tekstu.
int _bestTokenMatch(String queryToken, List<String> textTokens) {
  var best = 0;
  for (final textToken in textTokens) {
    // Prefiks to trafienie pelne: user pisze w trakcie i po kazdej literze lista ma sie
    // zawezac, a nie gasnac. Zapytanie "mowis" o tekst "mowisz" dostaje 100 zamiast 91,
    // a dwuznakowe "sp" zamiast 3 punktow (czyli pustej listy przy kazdym progu).
    if (textToken.startsWith(queryToken)) return 100;
    // Podobienstwo nie przekroczy 2*min(dlugosci)/suma dlugosci, bo tyle najwyzej moze byc
    // wspolnych znakow. Gdy ten sufit lezy pod progiem, liczenie odleglosci edycyjnej jest
    // strata czasu — a przy dlugim transkrypcie odpada tak wiekszosc porownan.
    final ceiling = 200 * min(queryToken.length, textToken.length) ~/
        (queryToken.length + textToken.length);
    if (ceiling <= best || ceiling < SearchService.threshold) continue;
    final score = ratio(queryToken, textToken);
    if (score > best) best = score;
  }
  return best;
}

class SearchService {
  /// Prog dobrany pomiarami na fuzzywuzzy 1.2.0 (patrz testy-straznicy): najgorsza zmierzona
  /// literowka jednoznakowa w slowie 5-literowym ("maslu" wobec "maslo") daje 80, a pary
  /// osobnych slow, ktore nie moga sie dopasowac, siegaja 60 ("mleko"/"maslo") i 56
  /// ("spotkanie"/"sniadanie"). 75 lezy miedzy tymi grupami z zapasem po obu stronach.
  static const threshold = 75;

  List<RecordingWithTags> search(List<RecordingWithTags> all, {String query = '', String? tag}) {
    var items = all;
    if (tag != null) {
      items = items.where((r) => r.tags.contains(tag)).toList();
    }
    final normalizedQuery = _normalize(query.trim());
    if (normalizedQuery.isEmpty) return items;
    final queryTokens = _tokenize(normalizedQuery);
    if (queryTokens.isEmpty) return items;

    final scored = <(int, RecordingWithTags, int)>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final fields = [
        _normalize(item.recording.transcript ?? ''),
        _normalize(item.tags.join(' ')),
        _normalize(item.recording.title ?? ''),
      ].where((field) => field.isNotEmpty).toList();
      if (fields.isEmpty) continue;

      // Dwie strategie, bo lapia rozne rzeczy. tokenSetRatio na calym polu radzi sobie z
      // zapytaniem szerszym niz tekst (czesc slow zapytania w ogole nie wystepuje), ale
      // literowke w pojedynczym slowie gubi doszczetnie: przeciecie tokenow jest wtedy puste
      // i porownywany jest krotki string z posortowanym CALYM transkryptem — zmierzone 10
      // punktow dla "spotaknie" wobec transkryptu ze slowem "spotkanie". Druga strategia
      // patrzy token po tokenie, wiec dlugosc tekstu jej nie rozciencza.
      var score = 0;
      for (final field in fields) {
        score = max(score, tokenSetRatio(normalizedQuery, field));
      }

      // Tokeny wszystkich pol w jednym worku: zapytanie "zakupy mleko" ma trafiac, gdy
      // "zakupy" jest tagiem, a "mleko" siedzi w transkrypcie. Agregacja przez minimum, bo
      // kazde slowo zapytania ma byc spelnione — srednia przepuszczalaby "mleko rower" na
      // samym "mleko".
      final textTokens = fields.expand(_tokenize).toList();
      var weakestToken = 100;
      for (final queryToken in queryTokens) {
        weakestToken = min(weakestToken, _bestTokenMatch(queryToken, textTokens));
        if (weakestToken <= score) break;
      }
      score = max(score, weakestToken);

      if (score >= threshold) scored.add((index, item, score));
    }
    // Remisy sa czeste (prefiks daje 100 kazdemu trafieniu), a `List.sort` w Darcie nie jest
    // stabilny — bez jawnego rozstrzygania kolejnosc wejscia (najnowsze pierwsze) tasowalaby sie.
    scored.sort((a, b) {
      final byScore = b.$3.compareTo(a.$3);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    return [for (final s in scored) s.$2];
  }
}
