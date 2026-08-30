import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/features/library/playback.dart';

void main() {
  group('nextPlaybackRate', () {
    test('cykl idzie po kolejnosci z makiety i wraca do 1.0', () {
      expect(nextPlaybackRate(1.0), 1.25);
      expect(nextPlaybackRate(1.25), 1.5);
      expect(nextPlaybackRate(1.5), 2.0);
      expect(nextPlaybackRate(2.0), 1.0);
    });

    test('wartosc spoza cyklu wraca na jego poczatek', () {
      // Nie da sie jej dzis ustawic z ekranu, ale funkcja nie ma prawa oddac czegos,
      // czego pigulka nie umie pokazac.
      expect(nextPlaybackRate(1.75), 1.0);
    });

    test('cykl domyka sie na kazdej wartosci z listy', () {
      var rate = kPlaybackRates.first;
      final seen = <double>[];
      for (var i = 0; i < kPlaybackRates.length; i++) {
        seen.add(rate);
        rate = nextPlaybackRate(rate);
      }
      expect(seen, kPlaybackRates);
      expect(rate, kPlaybackRates.first, reason: 'pelny obrot wraca na start');
    });
  });

  group('skipTarget', () {
    const total = Duration(seconds: 100);

    test('skok do przodu i do tylu przesuwa o podany krok', () {
      expect(skipTarget(const Duration(seconds: 30), kSkipStep, total),
          const Duration(seconds: 40));
      expect(skipTarget(const Duration(seconds: 30), -kSkipStep, total),
          const Duration(seconds: 20));
    });

    test('doly i gory sa przyciete do nagrania', () {
      expect(skipTarget(const Duration(seconds: 4), -kSkipStep, total), Duration.zero);
      expect(skipTarget(const Duration(seconds: 95), kSkipStep, total), total);
    });

    test('pozycja spoza nagrania tez konczy w zakresie', () {
      expect(skipTarget(const Duration(seconds: 500), kSkipStep, total), total);
      expect(skipTarget(const Duration(seconds: -5), -kSkipStep, total), Duration.zero);
    });

    test('nagranie o nieznanej dlugosci nie pozwala odplynac', () {
      expect(skipTarget(const Duration(seconds: 30), kSkipStep, Duration.zero), Duration.zero);
    });

    test('krok to 10 s w obie strony', () {
      expect(kSkipStep, const Duration(seconds: 10));
    });
  });

  group('playedBars', () {
    test('poczatek i koniec nagrania to skrajne podzialy', () {
      expect(playedBars(count: 44, position: Duration.zero, total: const Duration(seconds: 44)),
          0);
      expect(
          playedBars(
              count: 44,
              position: const Duration(seconds: 44),
              total: const Duration(seconds: 44)),
          44);
    });

    test('podzial idzie za wzorem z makiety: slupek i jest zagrany, gdy i/count < postep', () {
      // 34% z makiety: zagrane sa slupki 0..14, bo 14/44 = 0,318 < 0,34, a 15/44 = 0,341 juz nie.
      expect(
          playedBars(
              count: 44,
              position: const Duration(milliseconds: 34000),
              total: const Duration(milliseconds: 100000)),
          15);
    });

    test('granica slupka nalezy do niezagranych', () {
      // Dokladnie 10/44 nagrania: slupek 10 zaczyna sie w tym punkcie, wiec zostaje pusty.
      expect(
          playedBars(
              count: 44,
              position: const Duration(milliseconds: 10000),
              total: const Duration(milliseconds: 44000)),
          10);
      expect(
          playedBars(
              count: 44,
              position: const Duration(milliseconds: 10001),
              total: const Duration(milliseconds: 44000)),
          11,
          reason: 'milisekunda za granica zapala kolejny slupek');
    });

    test('pozycja poza nagraniem nie wychodzi poza liczbe slupkow', () {
      expect(
          playedBars(
              count: 44,
              position: const Duration(seconds: 500),
              total: const Duration(seconds: 44)),
          44);
      expect(
          playedBars(
              count: 44,
              position: const Duration(seconds: -5),
              total: const Duration(seconds: 44)),
          0);
    });

    test('bez dlugosci albo bez slupkow nie ma czego dzielic', () {
      expect(playedBars(count: 44, position: const Duration(seconds: 5), total: Duration.zero), 0);
      expect(playedBars(count: 0, position: const Duration(seconds: 5), total: const Duration(seconds: 44)), 0);
    });
  });

  group('positionAt', () {
    const total = Duration(seconds: 200);

    test('ulamek szerokosci przeklada sie na pozycje w nagraniu', () {
      expect(positionAt(dx: 0, width: 400, total: total), Duration.zero);
      expect(positionAt(dx: 200, width: 400, total: total), const Duration(seconds: 100));
      expect(positionAt(dx: 400, width: 400, total: total), total);
    });

    test('dotkniecie poza paskiem laduje na jego krancu', () {
      expect(positionAt(dx: -30, width: 400, total: total), Duration.zero);
      expect(positionAt(dx: 900, width: 400, total: total), total);
    });

    test('pasek o zerowej szerokosci nie dzieli przez zero', () {
      expect(positionAt(dx: 10, width: 0, total: total), Duration.zero);
    });
  });

  group('interpolatePosition', () {
    const total = Duration(seconds: 100);

    test('miedzy zdarzeniami pozycja rosnie o uplyw czasu', () {
      expect(
          interpolatePosition(
              base: const Duration(seconds: 10),
              elapsed: const Duration(milliseconds: 500),
              rate: 1.0,
              total: total),
          const Duration(milliseconds: 10500));
    });

    test('predkosc odtwarzania rozciaga uplyw czasu', () {
      expect(
          interpolatePosition(
              base: const Duration(seconds: 10),
              elapsed: const Duration(seconds: 2),
              rate: 2.0,
              total: total),
          const Duration(seconds: 14));
      expect(
          interpolatePosition(
              base: const Duration(seconds: 10),
              elapsed: const Duration(seconds: 4),
              rate: 1.25,
              total: total),
          const Duration(seconds: 15));
    });

    test('interpolacja nie wybiega poza koniec nagrania', () {
      expect(
          interpolatePosition(
              base: const Duration(seconds: 99),
              elapsed: const Duration(seconds: 30),
              rate: 2.0,
              total: total),
          total);
    });

    test('nagranie o nieznanej dlugosci nie ma gornej granicy, ale ma dolna', () {
      // Dlugosc zerowa znaczy "jeszcze nie wiadomo" — przycinanie do zera zatrzymaloby
      // kursor na starcie zamiast pozwolic mu isc.
      expect(
          interpolatePosition(
              base: const Duration(seconds: 5),
              elapsed: const Duration(seconds: 5),
              rate: 1.0,
              total: Duration.zero),
          const Duration(seconds: 10));
      expect(
          interpolatePosition(
              base: const Duration(seconds: -5),
              elapsed: Duration.zero,
              rate: 1.0,
              total: Duration.zero),
          Duration.zero);
    });

    test('rozdzielczosc schodzi ponizej klatki', () {
      // Klatka przy 60 Hz to okolo 16,7 ms. Liczenie na calych milisekundach elapsed
      // wystarcza, ale zaokraglenie nie ma prawa gubic calej klatki.
      expect(
          interpolatePosition(
              base: Duration.zero,
              elapsed: const Duration(microseconds: 16667),
              rate: 1.0,
              total: total),
          const Duration(milliseconds: 17));
    });
  });

  group('reconcilePosition', () {
    test('zdarzenie do przodu przejmuje prowadzenie', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 10), event: const Duration(milliseconds: 10200)),
          const Duration(milliseconds: 10200));
    });

    test('drobne cofniecie nie szarpie kursorem', () {
      // Zdarzenie o wlos ZA interpolacja to normalka; cofniecie kursora o kilkadziesiat
      // milisekund widac jako drganie.
      expect(
          reconcilePosition(
              shown: const Duration(milliseconds: 10200), event: const Duration(seconds: 10)),
          const Duration(milliseconds: 10200));
    });

    test('duzy skok w tyl jest prawdziwy i kursor idzie za nim od razu', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 100), event: const Duration(seconds: 3)),
          const Duration(seconds: 3));
    });

    test('duzy skok do przodu tez jest natychmiastowy', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 3), event: const Duration(seconds: 100)),
          const Duration(seconds: 100));
    });

    test('granica wygladzania jest domyslnie polsekundowa', () {
      expect(kPositionSnap, const Duration(milliseconds: 500));
      // Rowno na granicy jeszcze wygladzamy, dopiero powyzej snapujemy.
      expect(
          reconcilePosition(
              shown: const Duration(milliseconds: 1500), event: const Duration(seconds: 1)),
          const Duration(milliseconds: 1500));
      expect(
          reconcilePosition(
              shown: const Duration(milliseconds: 1501), event: const Duration(seconds: 1)),
          const Duration(seconds: 1));
    });
  });
}
