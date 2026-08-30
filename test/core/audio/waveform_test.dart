import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/waveform.dart';

void main() {
  group('reduceToBuckets', () {
    test('dzieli probki rowno i bierze szczyt z kazdego kubelka', () {
      // 8 probek -> 4 kubelki, po 2 probki na kubelek. Wartosci dobrane tak, ze kazdy
      // kubelek ma inny szczyt, wiec pomylka o jeden w granicach od razu zmienia wynik.
      final buckets = reduceToBuckets(
        [0.1, 0.2, 0.9, 0.3, 0.4, 0.5, 0.6, 1.0],
        buckets: 4,
      );
      expect(buckets, [0.2, 0.9, 0.5, 1.0]);
    });

    test('ostatnia probka trafia do ostatniego kubelka', () {
      // Straznik na off-by-one w gornej granicy: szczyt siedzi na samym koncu wejscia.
      final buckets = reduceToBuckets([0.1, 0.1, 0.1, 0.1, 0.1, 0.87], buckets: 3);
      expect(buckets.last, 0.87);
    });

    test('pierwsza probka trafia do pierwszego kubelka', () {
      // Straznik na off-by-one w dolnej granicy.
      final buckets = reduceToBuckets([0.93, 0.1, 0.1, 0.1, 0.1, 0.1], buckets: 3);
      expect(buckets.first, 0.93);
    });

    test('zwraca dokladnie zadana liczbe kubelkow przy nierownym podziale', () {
      final buckets = reduceToBuckets(List.filled(101, 0.5), buckets: kWaveformBuckets);
      expect(buckets, hasLength(kWaveformBuckets));
      expect(buckets.every((b) => b == 0.5), isTrue);
    });

    test('mniej probek niz kubelkow: kazdy kubelek dostaje najblizsza probke', () {
      // Krotkie nagranie nie moze wygenerowac dziur, bo puste kubelki wygladalyby
      // jak cisza, ktorej nie bylo.
      final buckets = reduceToBuckets([0.2, 0.8, 0.5], buckets: 6);
      expect(buckets, [0.2, 0.2, 0.8, 0.8, 0.5, 0.5]);
    });

    test('brak probek daje pusta liste', () {
      expect(reduceToBuckets([], buckets: kWaveformBuckets), isEmpty);
    });

    test('wartosci spoza zakresu sa przycinane do 0..1', () {
      expect(reduceToBuckets([-3.0, 2.5], buckets: 2), [0.0, 1.0]);
    });

    test('domyslna liczba kubelkow zgadza sie z makieta', () {
      expect(kWaveformBuckets, 44);
      expect(reduceToBuckets(List.filled(500, 0.3)), hasLength(44));
    });
  });

  group('kodowanie', () {
    test('runda w obie strony zachowuje ksztalt', () {
      final buckets = reduceToBuckets([0.125, 0.5, 0.875, 1.0], buckets: 4);
      expect(decodeWaveform(encodeWaveform(buckets)), buckets);
    });

    test('zapis skraca probki do trzech miejsc po przecinku', () {
      // Kolumna w bazie nie ma powodu puchnac od cyfr, ktorych slupek 56 px nie pokaze.
      expect(encodeWaveform([1 / 3]), '[0.333]');
    });

    test('brak zapisu daje null', () {
      expect(decodeWaveform(null), isNull);
      expect(decodeWaveform(''), isNull);
    });

    test('smieci w kolumnie daja null zamiast wyjatku', () {
      expect(decodeWaveform('nie-json'), isNull);
      expect(decodeWaveform('{"a":1}'), isNull);
      expect(decodeWaveform('[]'), isNull);
      expect(decodeWaveform('["a","b"]'), isNull);
    });

    test('odczyt przycina wartosci spoza zakresu', () {
      expect(decodeWaveform('[-1, 0.5, 4]'), [0.0, 0.5, 1.0]);
    });
  });
}
