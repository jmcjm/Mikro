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

  test('empty query without tag returns everything', () {
    expect(service.search(data), hasLength(3));
  });

  test('tag filter', () {
    final result = service.search(data, tag: 'praca');
    expect(result.map((r) => r.recording.id), ['praca']);
  });

  test('fuzzy matches despite typo', () {
    final result = service.search(data, query: 'mlko chleb');
    expect(result.first.recording.id, 'zakupy');
  });

  test('fuzzy matches by tag name', () {
    final result = service.search(data, query: 'zakupy');
    expect(result.map((r) => r.recording.id), contains('zakupy'));
  });

  test('mismatched query is dropped below threshold', () {
    final result = service.search(data, query: 'kwantowa chromodynamika glonow');
    expect(result.where((r) => r.recording.id == 'pusty'), isEmpty);
  });

  test('tag and query combine (AND)', () {
    final result = service.search(data, query: 'mleko', tag: 'praca');
    expect(result, isEmpty);
  });

  test('GUARD: results are sorted descending by score, not by insertion order', () {
    // Score measured with fuzzywuzzy 1.2.0 for query 'mleko chleb maslo'
    // (final score = max(tokenSetRatio, minimum over query tokens)):
    //   'mleko chleb maslo'      -> 100  (tokenSet 100 / by tokens 100)
    //   'mlko chlb maslo'        ->  94  (tokenSet  94 / by tokens  89)
    //   'chleb maslo w sklepie'  ->  79  (tokenSet  79 / by tokens  60)
    //   'chleb na sniadanie …'   ->  45  (tokenSet  45 / by tokens  29 — below threshold 75, dropped)
    // Ranking is the same as before adding per-token matching: tokenSet strategy
    // wins here for every row, so bumping the threshold from 55 to 75 changes nothing.
    // Input data is deliberately ordered INVERSELY to expected ranking: without sorting
    // the result would return in insertion order and the assertion would fail.
    final ranked = [
      item('slabo', 'chleb maslo w sklepie', []),
      item('ponizej-progu', 'chleb na sniadanie i dluga lista innych spraw', []),
      item('srednio', 'mlko chlb maslo', []),
      item('najlepiej', 'mleko chleb maslo', []),
    ];

    final result = service.search(ranked, query: 'mleko chleb maslo');

    expect(result.map((r) => r.recording.id).toList(), ['najlepiej', 'srednio', 'slabo'],
        reason: 'order must go from most relevant, and recording below threshold must be dropped');
  });

  // ---------------------------------------------------------------------------
  // Resilience to typos and missing Polish characters (bug report: "fuzzy search does not
  // work"). Each case below was RED under scoring based solely on
  // tokenSetRatio without normalization — measured values in comments.
  // ---------------------------------------------------------------------------

  const dlugiTranskrypt =
      'w czwartek rano mamy spotkanie z zespolem o architekturze pipeline i podziale zadan '
      'na kolejny sprint a potem lunch i przeglad backlogu z product ownerem';

  test('typo in single-word query matches long transcript', () {
    // Bare tokenSetRatio('spotaknie', dlugiTranskrypt) = 10 (vs 100 for correct spelling):
    // token intersection is empty, so a short string is compared to the sorted
    // string of the ENTIRE transcript. Matching must go by individual tokens.
    final data = [item('spotkanie', dlugiTranskrypt, []), item('inne', 'lista zakupow na sobote', [])];

    final result = service.search(data, query: 'spotaknie');

    expect(result.map((r) => r.recording.id), ['spotkanie']);
  });

  test('typo in multi-word query matches long transcript', () {
    final data = [item('spotkanie', dlugiTranskrypt, [])];

    expect(service.search(data, query: 'spotaknie zespolem').map((r) => r.recording.id),
        ['spotkanie']);
  });

  test('query without diacritics matches text with diacritics', () {
    // tokenSetRatio('sledzia', 'kupic śledzia w piątek') = 22 — 'ś' and 's' are two different
    // characters to the algorithm, so the entire token misses.
    final data = [item('ryba', 'kupic śledzia i zrobić zakupy w piątek', [])];

    expect(service.search(data, query: 'sledzia').map((r) => r.recording.id), ['ryba']);
    expect(service.search(data, query: 'piatek').map((r) => r.recording.id), ['ryba']);
    expect(service.search(data, query: 'zrobic zakupy').map((r) => r.recording.id), ['ryba']);
  });

  test('word with multiple diacritics matches without diacritics', () {
    // A single diacritic in a longer word is still passed by raw similarity (ratio 'sledzia'
    // to 'śledzia' = 86), so the cases above do not guard diacritic folding as strictly
    // as it seems. Only multiple diacritics in one word push score below threshold:
    // 'ksiazke'/'książkę' = 57, 'zolw'/'żółw' = 25. Without folding these two stand no chance.
    final data = [item('biblioteka', 'oddac książkę o żółwiach do biblioteki', [])];

    expect(service.search(data, query: 'ksiazke').map((r) => r.recording.id), ['biblioteka']);
    expect(service.search(data, query: 'zolwiach').map((r) => r.recording.id), ['biblioteka']);
  });

  test('query with diacritics matches text without diacritics', () {
    final data = [item('ryba', 'kupic sledzia w piatek', [])];

    expect(service.search(data, query: 'śledzia').map((r) => r.recording.id), ['ryba']);
  });

  test('query without diacritics matches tag with diacritics', () {
    final data = [item('praca', 'notatka bez slow kluczowych', ['środa'])];

    expect(service.search(data, query: 'sroda').map((r) => r.recording.id), ['praca']);
  });

  test('case does not matter on either side', () {
    // fuzzywuzzy 1.2.0 does NOT have a default processor: ratio('ABC', 'abc') = 0. Both sides
    // must be lowercased manually — data tag may start with uppercase.
    final data = [item('zakupy', 'Kupic Mleko I Chleb', ['Zakupy'])];

    expect(service.search(data, query: 'MLEKO').map((r) => r.recording.id), ['zakupy']);
    expect(service.search(data, query: 'zakupy').map((r) => r.recording.id), ['zakupy']);
  });

  test('recording title is in search scope', () {
    // Library card displays title, falling back to transcript only when title is absent
    // (library_screen.dart). A word visible on the card must be searchable.
    final data = [item('tytulowe', 'dlugi tekst zupelnie o czym innym', [], title: 'Plan wyjazdu')];

    expect(service.search(data, query: 'wyjazdu').map((r) => r.recording.id), ['tytulowe']);
    expect(service.search(data, query: 'wyjadzu').map((r) => r.recording.id), ['tytulowe']);
  });

  test('two distinct words do not match', () {
    // Threshold boundary from the other side: 'mleko' vs 'maslo' = 60, 'spotkanie' vs 'sniadanie' = 56.
    // The threshold must lie below the worst measured typo (80) and above these pairs.
    final data = [
      item('mleko', 'kupic mleko', []),
      item('spotkanie', 'spotkanie z zespolem', []),
    ];

    expect(service.search(data, query: 'maslo'), isEmpty);
    expect(service.search(data, query: 'sniadanie'), isEmpty);
  });

  test('short query acts as prefix and does not return empty results', () {
    // A 1-2 character query scored by similarity alone scores around 1-3, so at
    // any threshold it wiped the ENTIRE list while typing. Deliberate decision: query token
    // being a prefix of text token is a full match regardless of length.
    final data = [
      item('zakupy', 'kupic mleko i chleb', []),
      item('praca', 'spotkanie z zespolem', []),
    ];

    expect(service.search(data, query: 'sp').map((r) => r.recording.id), ['praca']);
    expect(service.search(data, query: 'ml').map((r) => r.recording.id), ['zakupy']);
    expect(service.search(data, query: 'spotk').map((r) => r.recording.id), ['praca']);
    expect(service.search(data, query: 'xq'), isEmpty);
  });

  test('insertion order breaks ties in scoring', () {
    // Prefix matches yield 100 to each match, so ties are the rule rather than exception. `List.sort`
    // in Dart switches to unstable sort above 32 elements, so the list must be
    // longer than this threshold — on two elements a mutation removing tie-breaking
    // passes unnoticed. Insertion order is database order (newest first)
    // and only that makes sense for tie-breaking.
    final data = [
      for (var i = 0; i < 40; i++) item('n$i', 'spotkanie numer $i z zespolem', []),
    ];

    expect(service.search(data, query: 'spot').map((r) => r.recording.id),
        [for (var i = 0; i < 40; i++) 'n$i']);
  });

  // ---------------------------------------------------------------------------
  // Device repro (user report: "search works only on full words").
  // Three queries against the same transcript: literal worked, prefix and version
  // without diacritics returned NOTHING. This is the main calibration of the threshold —
  // the remaining cases only guard boundaries.
  // ---------------------------------------------------------------------------
  group('device repro: "jak mowisz"', () {
    final data = [
      item('mowisz', 'nagrywam notatke zeby sprawdzic jak mówisz o tym projekcie na spotkaniu', []),
      item('inne', 'lista zakupow na sobote i niedziele', []),
    ];

    test('literal query matches (worked previously, must not regress)', () {
      expect(service.search(data, query: 'jak mówisz').map((r) => r.recording.id), ['mowisz']);
    });

    test('prefix without trailing character matches', () {
      expect(service.search(data, query: 'jak mówis').map((r) => r.recording.id), ['mowisz']);
    });

    test('query without diacritics matches', () {
      expect(service.search(data, query: 'jak mowisz').map((r) => r.recording.id), ['mowisz']);
    });

    test('prefix without diacritics and without trailing character matches', () {
      expect(service.search(data, query: 'jak mowis').map((r) => r.recording.id), ['mowisz']);
    });
  });
}
