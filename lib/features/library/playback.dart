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

/// Roznica, powyzej ktorej zdarzenie pozycji przestaje byc korekta, a staje sie skokiem.
/// Polsekundy: zdarzenia przychodza co 200 ms - 1 s, wiec drobne rozjechanie sie miesci sie
/// grubo ponizej, a prawdziwy skok (przewiniecie, koniec nagrania) grubo powyzej.
const Duration kPositionSnap = Duration(milliseconds: 500);

/// Pozycja odtwarzania miedzy zdarzeniami: baza plus uplyw czasu przemnozony przez predkosc.
///
/// Odtwarzacz melduje pozycje co 200 ms - 1 s. Kursor postawiony wprost na tych zdarzeniach
/// skacze; ten sam kursor liczony z uplywu czasu miedzy nimi sunie. Predkosc wchodzi tu
/// wprost, bo przy 2,0x sekunda zegara to dwie sekundy nagrania.
///
/// [total] zerowe znaczy „dlugosc jeszcze nieznana" i zdejmuje gorna granice — przycinanie
/// do zera zatrzymaloby kursor na starcie zamiast pozwolic mu isc.
Duration interpolatePosition({
  required Duration base,
  required Duration elapsed,
  required double rate,
  required Duration total,
}) {
  // Mikrosekundy, bo klatka przy 60 Hz to 16,7 ms i zaokraglenie do milisekund na wejsciu
  // gubiloby co szesnasta.
  final ms = base.inMilliseconds + (elapsed.inMicroseconds * rate / 1000).round();
  final maxMs = total.inMilliseconds;
  if (ms < 0) return Duration.zero;
  if (maxMs > 0 && ms > maxMs) return total;
  return Duration(milliseconds: ms);
}

/// Nowa baza interpolacji po prawdziwym zdarzeniu pozycji.
///
/// Zdarzenie potrafi byc o wlos ZA tym, co karta juz pokazala — cofniecie kursora o kilkadziesiat
/// milisekund widac jako drganie, wiec przy malych roznicach zostaje wartosc dalsza. Duza roznica
/// to nie drganie, tylko prawdziwy skok (przewiniecie spoza karty, koniec nagrania) i tam kursor
/// idzie za odtwarzaczem natychmiast.
Duration reconcilePosition({
  required Duration shown,
  required Duration event,
  Duration snapAbove = kPositionSnap,
}) {
  final delta = event - shown;
  if (delta.abs() > snapAbove) return event;
  return delta.isNegative ? shown : event;
}

/// Okresy „oddechu" slupkow w sekundach. Wolniejsze niz skoki poziomu na ekranie nagrywania
/// (tam ~1 s): tam slupki SA animacja, tu sa wykresem, ktory ma tylko zyc.
const List<double> kBarDanceSeconds = [2.6, 2.2, 3.1, 2.4, 2.9, 2.3, 2.8, 2.5, 3.0];

/// Ujemne opoznienia startu w sekundach. SIEDEM wartosci przy dziewieciu okresach: para
/// (okres, opoznienie) powtarza sie dopiero co 63 slupki, czyli nigdy w pasie [kWaveformBuckets]
/// slupkow. Przy rownej dlugosci obu list co dziewiaty slupek oddychalby identycznie i w pasie
/// widac by bylo wzor; bez opoznien caly pas pulsowalby unisono jak jeden klocek.
const List<double> kBarDanceDelays = [-2.1, -0.5, -1.3, 0.0, -1.7, -0.9, -0.3];

/// Glebokosc oddechu: slupek plywa miedzy `1 - kBarDanceDepth` a pelna wysokoscia z obwiedni.
///
/// Waskie pasmo jest tu calym sednem. Przy szerokim (proba z zakresem 0,25-1,0 jak na ekranie
/// nagrywania) pas przestawal byc wykresem i stawal sie ekwalizerem: slupek cichy w szczycie
/// swojego cyklu bywal wyzszy od glosnego w dolku, czyli animacja ZAMAZYWALA to, co w nagraniu
/// slychac. Przy 0,15 stosunek skrajnych mnoznikow to 1,18, wiec porzadek wysokosci zgadza sie
/// z obwiednia wszedzie tam, gdzie slupki roznia sie o wiecej niz osiemnascie procent —
/// a zatrzymana klatka animacji jest prawie nie do odroznienia od statycznego wykresu.
const double kBarDanceDepth = 0.15;

/// Wysokosc slupka przebiegu w trakcie odtwarzania, 0..1.
///
/// Slupek oddycha WOKOL swojej prawdziwej wysokosci, w waskim pasmie pod nia — mnozenie przez
/// [level] znaczy, ze animacja skaluje obwiednie, a nie zastepuje jej wlasnym ksztaltem.
///
/// Ksztalt cyklu wprost z makiety (`@keyframes bar { 0%,100% { scaleY(.25) } 50% { scaleY(1) } }`):
/// trojkat, a nie pila — na zawinieciu cyklu slupek nie spada skokiem. Argumentem jest
/// MONOTONICZNY czas od startu odtwarzania, dokladnie jak w `phaseAt` z ekranu nagrywania:
/// zegar, ktory nigdy nie wraca do zera, nie tnie zadnego okresu.
double dancingBarLevel({
  required double level,
  required double elapsedSeconds,
  required int index,
}) {
  final period = kBarDanceSeconds[index % kBarDanceSeconds.length];
  final delay = kBarDanceDelays[index % kBarDanceDelays.length];
  final phase = ((elapsedSeconds - delay) / period) % 1.0;
  final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return level.clamp(0.0, 1.0) * (1 - kBarDanceDepth + kBarDanceDepth * wave);
}
