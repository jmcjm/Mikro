// Logika sterowania odtwarzaniem z karty szczegolow. Siedzi poza widgetem, bo daje sie
// wtedy sprawdzic bez stawiania ekranu i bez natywnego odtwarzacza — a to wlasnie te
// przeliczenia decyduja o tym, czy suwak, kursor i czasy mowia to samo.

/// Predkosci odtwarzania w kolejnosci cyklu pigulki. Cztery kroki, bo dalej roznica przestaje
/// byc slyszalna, a etykieta rosnie szybciej niz pozytek.
const List<double> kPlaybackRates = [1.0, 1.25, 1.5, 2.0];

/// Skok przyciskow replay_10 i forward_10. Dziesiec sekund wprost z ikon makiety.
const Duration kSkipStep = Duration(seconds: 10);

/// Nastepna predkosc w cyklu; po ostatniej wraca pierwsza.
///
/// Wartosc spoza listy (nie da sie jej dzis ustawic z ekranu) laduje na jej poczatku —
/// pigulka umie pokazac tylko te cztery i nie wolno jej zostawic z etykieta bez pokrycia.
double nextPlaybackRate(double current) {
  final index = kPlaybackRates.indexOf(current);
  if (index < 0) return kPlaybackRates.first;
  return kPlaybackRates[(index + 1) % kPlaybackRates.length];
}

/// Cel skoku o [step] od pozycji [from], przyciety do nagrania.
///
/// Przyciecie jest tu, a nie w odtwarzaczu, bo to samo miejsce liczy pozycje pokazywana na
/// karcie: gdyby ekran wyslal seek poza koniec, natywna warstwa przyciela by go po cichu,
/// a licznik pokazywalby przez chwile czas, ktorego w nagraniu nie ma.
///
/// Nagranie o nieznanej dlugosci ([total] zerowe) nie ma zakresu, w ktorym skok mialby sens:
/// wynikiem jest poczatek.
Duration skipTarget(Duration from, Duration step, Duration total) {
  final totalMs = total.inMilliseconds;
  if (totalMs <= 0) return Duration.zero;
  return Duration(milliseconds: (from.inMilliseconds + step.inMilliseconds).clamp(0, totalMs));
}

/// Ile slupkow przebiegu stoi po lewej stronie kursora, czyli ile z nich jest juz zagranych.
///
/// Warunek jest ten sam, co w generatorze makiety (`i / count < played`), tylko trzymany na
/// liczbach calkowitych: podzial nie ma prawa skakac przez blad zaokraglenia double, bo
/// pilnuje go test na granicy slupka.
int playedBars({required int count, required Duration position, required Duration total}) {
  final totalMs = total.inMilliseconds;
  if (count <= 0 || totalMs <= 0) return 0;
  final positionMs = position.inMilliseconds.clamp(0, totalMs);
  // Sufit z dzielenia calkowitego: tyle jest indeksow i, dla ktorych i/count < pozycja/calosc.
  final played = (positionMs * count + totalMs - 1) ~/ totalMs;
  return played.clamp(0, count);
}

/// Pozycja w nagraniu pod punktem [dx] powierzchni przebiegu o szerokosci [width].
///
/// Dotkniecie poza paskiem (palec wyjezdzajacy w bok w trakcie przeciagania) laduje na jego
/// krancu — nie ma powodu, zeby gest przerywal sie tylko dlatego, ze reka wyszla poza karte.
Duration positionAt({required double dx, required double width, required Duration total}) {
  if (width <= 0 || total <= Duration.zero) return Duration.zero;
  final fraction = (dx / width).clamp(0.0, 1.0);
  return Duration(milliseconds: (total.inMilliseconds * fraction).round());
}
