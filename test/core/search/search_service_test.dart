import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/search/search_service.dart';

RecordingWithTags item(String id, String? transcript, List<String> tags) => RecordingWithTags(
      recording: Recording(
        id: id,
        createdAt: DateTime.utc(2026),
        durationMs: 1000,
        audioPath: '/x',
        status: RecordingStatus.done,
        transcript: transcript,
        providerUsed: null,
        errorMessage: null,
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
    // Punktacja zmierzona na fuzzywuzzy 1.2.0 dla query 'mleko chleb maslo':
    //   'mleko chleb maslo'      -> 100
    //   'mlko chlb maslo'        ->  94
    //   'chleb maslo w sklepie'  ->  79
    //   'chleb na sniadanie …'   ->  45  (ponizej progu 55, wypada)
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
}
