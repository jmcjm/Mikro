import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prog, powyzej ktorego aplikacja przechodzi na uklad szeroki: nawigacja idzie z dolu na bok,
/// a biblioteka rozklada sie na liste i panel szczegolow. Makieta pokazuje ten wariant na
/// ekranie 1280 px i nie podaje wlasnego progu ani media query, wiec zostaje standard MD3 dla
/// klasy "medium" — 840 dp. Jedna stala, bo oba przelaczenia musza nastapic w tym samym
/// momencie: rail bez panelu (albo odwrotnie) to uklad, ktorego makieta nie przewiduje.
const wideLayoutBreakpoint = 840.0;

/// Zakladki powloki. Nazwane stale zamiast golych liczb, bo do tej trojki siega teraz
/// kilka miejsc poza sama powloka — pusty stan biblioteki, ikona historii na ekranie
/// Nagrywaj, akcja snackbara i rail — a literal `1` rozsiany po ekranach nie mowilby nic.
abstract final class HomeTab {
  static const recorder = 0;
  static const library = 1;
  static const settings = 2;

  /// Liczba destynacji. Pilnuje, zeby [HomeTabController.select] nie przyjal indeksu,
  /// ktorego IndexedStack nie ma czym obsluzyc.
  static const count = 3;
}

/// Aktywna zakladka powloki. Wyniesiona z lokalnego `setState` HomeShella, bo przelaczaja
/// ja teraz takze ekrany w srodku IndexedStacka — przekazywanie callbacku przez cale drzewo
/// byloby tu jedyna alternatywa.
class HomeTabController extends Notifier<int> {
  @override
  int build() => HomeTab.recorder;

  void select(int index) {
    assert(index >= 0 && index < HomeTab.count, 'nieznana zakladka: $index');
    state = index;
  }
}

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);
