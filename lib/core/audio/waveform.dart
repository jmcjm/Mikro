import 'dart:convert';

/// Liczba slupkow przebiegu na karcie odtwarzacza. Wprost z makiety (Mikro-MD3.dc.html,
/// generator listy `wave`): 44 slupki po 3 px odstepu w pasku o wysokosci 56 px.
const int kWaveformBuckets = 44;

/// Redukuje strumien probek amplitudy (0..1, jedna co 200 ms) do stalej liczby kubelkow.
///
/// Kubelek dostaje SZCZYT swojego wycinka, bo rysujemy obwiednie amplitudy: slupek ma
/// odpowiadac na pytanie "jak glosno bylo w tym fragmencie", a nie usredniac przerwy
/// w mowie do plaskiej kreski. Granice licza sie na liczbach calkowitych
/// (`i * n ~/ buckets`), wiec podzial jest deterministyczny takze wtedy, gdy liczba probek
/// nie dzieli sie przez liczbe kubelkow: pierwsza i ostatnia probka zawsze wpadaja do
/// skrajnych kubelkow.
///
/// Nagranie krotsze niz [buckets] probek (ponizej ~9 s) rozciaga sie: kubelek bez wlasnego
/// wycinka bierze najblizsza probke. Dziura znaczylaby cisze, ktorej nie bylo.
List<double> reduceToBuckets(List<double> samples, {int buckets = kWaveformBuckets}) {
  if (samples.isEmpty || buckets <= 0) return const [];
  final n = samples.length;
  final out = <double>[];
  for (var i = 0; i < buckets; i++) {
    final start = i * n ~/ buckets;
    var end = (i + 1) * n ~/ buckets;
    if (end <= start) end = start + 1;
    if (end > n) end = n;
    var peak = 0.0;
    for (var j = start; j < end; j++) {
      final v = samples[j].clamp(0.0, 1.0);
      if (v > peak) peak = v;
    }
    out.add(peak);
  }
  return out;
}

/// Serializacja do kolumny `waveform`: zwykla tablica JSON. Wartosci ida z dokladnoscia do
/// trzech miejsc po przecinku — slupek ma 56 px wysokosci, wiec dalsze cyfry to tylko
/// puchnaca baza (44 x 20 znakow zamiast 44 x 5).
String encodeWaveform(List<double> buckets) =>
    jsonEncode([for (final b in buckets) (b.clamp(0.0, 1.0) * 1000).round() / 1000]);

/// Odczyt kolumny `waveform`. Zwraca null dla braku danych ORAZ dla zapisu, ktorego nie da
/// sie zinterpretowac — ekran ma wtedy pokazac stan pusty, a nie wywalic sie na nagraniu
/// sprzed migracji albo na uszkodzonym wierszu.
List<double>? decodeWaveform(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (data is! List || data.isEmpty) return null;
  final out = <double>[];
  for (final v in data) {
    if (v is! num || !v.isFinite) return null;
    out.add(v.toDouble().clamp(0.0, 1.0));
  }
  return out;
}
