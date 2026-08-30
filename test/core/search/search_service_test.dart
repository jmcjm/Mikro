import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/search/search_service.dart';

RecordingWithTags item(String id, String? transcript, List<String> tags, {String? title}) =>
    RecordingWithTags(
      recording: Recording(
        id: id,
        createdAt: DateTime.utc(2026),
        durationMs: 1000,
        audioPath: '/x',
        status: RecordingStatus.done,
        transcript: transcript,
        providerUsed: null,
        errorMessage: null,
        title: title,
      ),
      tags: tags,
    );

void main() {
  final service = SearchService();
  final data = [
    item('zakupy', 'kupic mleko chleb i maslo w biedronce', ['zakupy', 'dom']),
    item('praca', 'spotkanie z zespolem o architekturze pipeline', ['praca']),
    item('pusty', null, []),
  ];

  test('puste query bez taga zwraca wszystko', () {
    expect(service.search(data), hasLength(3));
  });

  test('filtr taga', () {
    final result = service.search(data, tag: 'praca');
    expect(result.map((r) => r.recording.id), ['praca']);
  });

  test('fuzzy znajduje mimo literowki', () {
    final result = service.search(data, query: 'mlko chleb');
    expect(result.first.recording.id, 'zakupy');
  });

  test('fuzzy dopasowuje po nazwie taga', () {
    final result = service.search(data, query: 'zakupy');
    expect(result.map((r) => r.recording.id), contains('zakupy'));
  });

  test('nietrafione query odpada ponizej progu', () {
    final result = service.search(data, query: 'kwantowa chromodynamika glonow');
    expect(result.where((r) => r.recording.id == 'pusty'), isEmpty);
  });

  test('tag i query lacza sie (AND)', () {
    final result = service.search(data, query: 'mleko', tag: 'praca');
    expect(result, isEmpty);
  });

  test('STRAZNIK: wyniki sa sortowane malejaco po trafnosci, nie po kolejnosci wejscia', () {
    // Punktacja zmierzona na fuzzywuzzy 1.2.0 dla query 'mleko chleb maslo'
    // (wynik koncowy = max(tokenSetRatio, minimum po tokenach zapytania)):
    //   'mleko chleb maslo'      -> 100  (tokenSet 100 / po tokenach 100)
    //   'mlko chlb maslo'        ->  94  (tokenSet  94 / po tokenach  89)
    //   'chleb maslo w sklepie'  ->  79  (tokenSet  79 / po tokenach  60)
    //   'chleb na sniadanie …'   ->  45  (tokenSet  45 / po tokenach  29 — ponizej progu 75, wypada)
    // Ranking jest ten sam co przed dolozeniem dopasowania po tokenach: strategia tokenSet
    // wygrywa tu w kazdym wierszu, wiec podniesienie progu z 55 na 75 niczego nie przestawia.
    // Dane wejsciowe sa celowo ulozone ODWROTNIE do oczekiwanego rankingu: bez sortowania
    // wynik wrocilby w kolejnosci wejscia i asercja by tego nie przepuscila.
    final ranked = [
      item('slabo', 'chleb maslo w sklepie', []),
      item('ponizej-progu', 'chleb na sniadanie i dluga lista innych spraw', []),
      item('srednio', 'mlko chlb maslo', []),
      item('najlepiej', 'mleko chleb maslo', []),
    ];

    final result = service.search(ranked, query: 'mleko chleb maslo');

    expect(result.map((r) => r.recording.id).toList(), ['najlepiej', 'srednio', 'slabo'],
        reason: 'kolejnosc ma isc od najtrafniejszego, a nagranie ponizej progu ma wypasc');
  });

  // ---------------------------------------------------------------------------
  // Odpornosc na literowki i brak polskich znakow (zgloszenie: "fuzzy search nie
  // dziala"). Kazdy przypadek nizej byl RED na scoringu opartym o samo
  // tokenSetRatio bez normalizacji — zmierzone wartosci w komentarzach.
  // ---------------------------------------------------------------------------

  const dlugiTranskrypt =
      'w czwartek rano mamy spotkanie z zespolem o architekturze pipeline i podziale zadan '
      'na kolejny sprint a potem lunch i przeglad backlogu z product ownerem';

  test('literowka w jednoslownym zapytaniu trafia w dlugi transkrypt', () {
    // Samo tokenSetRatio('spotaknie', dlugiTranskrypt) = 10 (przy 100 dla poprawnej pisowni):
    // przeciecie tokenow jest puste, wiec porownywany jest krotki string z posortowanym
    // stringiem CALEGO transkryptu. Dopasowanie musi isc po pojedynczych tokenach.
    final data = [item('spotkanie', dlugiTranskrypt, []), item('inne', 'lista zakupow na sobote', [])];

    final result = service.search(data, query: 'spotaknie');

    expect(result.map((r) => r.recording.id), ['spotkanie']);
  });

  test('literowka w wieloslownym zapytaniu trafia w dlugi transkrypt', () {
    final data = [item('spotkanie', dlugiTranskrypt, [])];

    expect(service.search(data, query: 'spotaknie zespolem').map((r) => r.recording.id),
        ['spotkanie']);
  });

  test('zapytanie bez ogonkow trafia w tekst z ogonkami', () {
    // tokenSetRatio('sledzia', 'kupic śledzia w piątek') = 22 — 'ś' i 's' to dla algorytmu
    // dwa rozne znaki, wiec caly token jest nietrafiony.
    final data = [item('ryba', 'kupic śledzia i zrobić zakupy w piątek', [])];

    expect(service.search(data, query: 'sledzia').map((r) => r.recording.id), ['ryba']);
    expect(service.search(data, query: 'piatek').map((r) => r.recording.id), ['ryba']);
    expect(service.search(data, query: 'zrobic zakupy').map((r) => r.recording.id), ['ryba']);
  });

  test('slowo z kilkoma ogonkami trafia bez ogonkow', () {
    // Jeden ogonek w dluzszym slowie samo podobienstwo jeszcze przepuszcza (ratio 'sledzia'
    // do 'śledzia' = 86), wiec przypadki wyzej nie pilnuja zwijania diakrytykow tak mocno,
    // jak by sie wydawalo. Dopiero kilka ogonkow w jednym slowie zbija wynik pod prog:
    // 'ksiazke'/'książkę' = 57, 'zolw'/'żółw' = 25. Bez zwijania te dwa nie maja szans.
    final data = [item('biblioteka', 'oddac książkę o żółwiach do biblioteki', [])];

    expect(service.search(data, query: 'ksiazke').map((r) => r.recording.id), ['biblioteka']);
    expect(service.search(data, query: 'zolwiach').map((r) => r.recording.id), ['biblioteka']);
  });

  test('zapytanie z ogonkami trafia w tekst bez ogonkow', () {
    final data = [item('ryba', 'kupic sledzia w piatek', [])];

    expect(service.search(data, query: 'śledzia').map((r) => r.recording.id), ['ryba']);
  });

  test('zapytanie bez ogonkow trafia w tag z ogonkami', () {
    final data = [item('praca', 'notatka bez slow kluczowych', ['środa'])];

    expect(service.search(data, query: 'sroda').map((r) => r.recording.id), ['praca']);
  });

  test('wielkosc liter nie ma znaczenia po zadnej ze stron', () {
    // fuzzywuzzy 1.2.0 NIE ma domyslnego procesora: ratio('ABC', 'abc') = 0. Obie strony
    // trzeba sprowadzic do malych liter samodzielnie — tag w danych bywa z wielkiej litery.
    final data = [item('zakupy', 'Kupic Mleko I Chleb', ['Zakupy'])];

    expect(service.search(data, query: 'MLEKO').map((r) => r.recording.id), ['zakupy']);
    expect(service.search(data, query: 'zakupy').map((r) => r.recording.id), ['zakupy']);
  });

  test('tytul nagrania jest w zakresie wyszukiwania', () {
    // Karta w bibliotece pokazuje tytul, a transkrypt dopiero gdy tytulu nie ma
    // (library_screen.dart). Slowo widoczne na karcie musi dac sie wyszukac.
    final data = [item('tytulowe', 'dlugi tekst zupelnie o czym innym', [], title: 'Plan wyjazdu')];

    expect(service.search(data, query: 'wyjazdu').map((r) => r.recording.id), ['tytulowe']);
    expect(service.search(data, query: 'wyjadzu').map((r) => r.recording.id), ['tytulowe']);
  });

  test('dwa rozne slowa nie sa dopasowaniem', () {
    // Granica progu od drugiej strony: 'mleko' vs 'maslo' = 60, 'spotkanie' vs 'sniadanie' = 56.
    // Prog musi lezec ponizej najgorszej zmierzonej literowki (80) i powyzej tych par.
    final data = [
      item('mleko', 'kupic mleko', []),
      item('spotkanie', 'spotkanie z zespolem', []),
    ];

    expect(service.search(data, query: 'maslo'), isEmpty);
    expect(service.search(data, query: 'sniadanie'), isEmpty);
  });

  test('krotkie zapytanie dziala jak prefiks, a nie zwraca pustki', () {
    // Zapytanie 1-2 znakowe punktowane samym podobienstwem ma wynik rzedu 1-3, wiec przy
    // kazdym progu wycinalo CALA liste w trakcie pisania. Swiadoma decyzja: token zapytania
    // bedacy prefiksem tokenu tekstu to trafienie pelne, niezaleznie od dlugosci.
    final data = [
      item('zakupy', 'kupic mleko i chleb', []),
      item('praca', 'spotkanie z zespolem', []),
    ];

    expect(service.search(data, query: 'sp').map((r) => r.recording.id), ['praca']);
    expect(service.search(data, query: 'ml').map((r) => r.recording.id), ['zakupy']);
    expect(service.search(data, query: 'spotk').map((r) => r.recording.id), ['praca']);
    expect(service.search(data, query: 'xq'), isEmpty);
  });

  test('kolejnosc wejscia rozstrzyga remisy w punktacji', () {
    // Prefiks daje 100 kazdemu trafieniu, wiec remisy sa regula, a nie wyjatkiem. `List.sort`
    // w Darcie przechodzi powyzej 32 elementow na sortowanie niestabilne, wiec lista musi byc
    // dluzsza niz ten prog — na dwoch elementach mutacja usuwajaca rozstrzyganie remisow
    // przechodzi niezauwazona. Kolejnosc wejscia to kolejnosc z bazy (najnowsze pierwsze)
    // i tylko ona ma sens jako rozstrzygniecie.
    final data = [
      for (var i = 0; i < 40; i++) item('n$i', 'spotkanie numer $i z zespolem', []),
    ];

    expect(service.search(data, query: 'spot').map((r) => r.recording.id),
        [for (var i = 0; i < 40; i++) 'n$i']);
  });

  // ---------------------------------------------------------------------------
  // Repro z urzadzenia (zgloszenie usera: "szukanie dziala tylko po pelnych slowach").
  // Trzy zapytania o ten sam transkrypt: doslowne dziala, prefiks i wersja bez ogonka
  // nie zwracaly NICZEGO. To jest glowna kalibracja progu — reszta przypadkow tylko
  // pilnuje granic.
  // ---------------------------------------------------------------------------
  group('repro z urzadzenia: "jak mowisz"', () {
    final data = [
      item('mowisz', 'nagrywam notatke zeby sprawdzic jak mówisz o tym projekcie na spotkaniu', []),
      item('inne', 'lista zakupow na sobote i niedziele', []),
    ];

    test('doslowne zapytanie trafia (dzialalo, nie wolno zepsuc)', () {
      expect(service.search(data, query: 'jak mówisz').map((r) => r.recording.id), ['mowisz']);
    });

    test('prefiks bez koncowego znaku trafia', () {
      expect(service.search(data, query: 'jak mówis').map((r) => r.recording.id), ['mowisz']);
    });

    test('zapytanie bez ogonka trafia', () {
      expect(service.search(data, query: 'jak mowisz').map((r) => r.recording.id), ['mowisz']);
    });

    test('prefiks bez ogonka i bez koncowego znaku trafia', () {
      expect(service.search(data, query: 'jak mowis').map((r) => r.recording.id), ['mowisz']);
    });
  });
}
