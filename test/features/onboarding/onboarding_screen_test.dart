import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/onboarding/onboarding_providers.dart';
import 'package:mikro/features/onboarding/onboarding_screen.dart';
import 'package:mikro/features/onboarding/onboarding_widgets.dart';
import 'package:mikro/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stoi za krokiem uprawnien: wtyczka nagrywania sama pokazuje systemowy dialog, wiec test
/// podmienia tylko jej odpowiedz i liczy zapytania.
class StubRecorder implements MikroRecorder {
  StubRecorder({required this.granted});

  final bool granted;
  var asked = 0;

  @override
  String get fileExtension => 'm4a';
  @override
  Future<bool> hasPermission() async {
    asked++;
    return granted;
  }

  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<double> amplitude() => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

// Ekran ustawien czyta konfiguracje w initState — bez podmiany magazynu klucza test wpadlby
// na kanal platformowy flutter_secure_storage.
class FakeKeyStore implements KeyStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

/// Krok powitalny animuje sie w kolko (blob z designu), wiec pumpAndSettle nigdy by nie wrocil.
/// Wszedzie ponizej przewijamy czas jawnie.
Future<void> settleFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<SharedPreferences> pumpOnboarding(WidgetTester tester, {StubRecorder? recorder}) async {
  // Domyslne okno testowe (800x600) jest nizsze niz telefon, dla ktorego narysowano design,
  // wiec kafelki lezalyby pod krawedzia. Testujemy na wymiarze z makiety.
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      recorderProvider.overrideWithValue(recorder ?? StubRecorder(granted: true)),
      keyStoreProvider.overrideWithValue(FakeKeyStore()),
    ],
    child: const MaterialApp(home: OnboardingScreen()),
  ));
  await tester.pump();
  return prefs;
}

Future<void> tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleFrames(tester);
}

void main() {
  testWidgets('pierwszy krok wita tekstem z designu', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Mów.\nMikro zapisze\ni otaguje.'), findsOneWidget);
    expect(find.text('Dalej'), findsOneWidget);
  });

  testWidgets('trzy kroki, a flage podnosi dopiero ostatni', (tester) async {
    final prefs = await pumpOnboarding(tester);

    await tapNext(tester, 'Dalej');
    expect(find.text('Dostęp do mikrofonu'), findsOneWidget);
    expect(find.text('Wymagany do nagrywania'), findsOneWidget);

    await tapNext(tester, 'Dalej');
    expect(find.text('Klucz API'), findsOneWidget);
    expect(find.text('Groq lub OpenAI — możesz dodać później'), findsOneWidget);
    expect(find.text('Dalej'), findsNothing);
    expect(prefs.get(onboardingCompletedKey), isNull,
        reason: 'przerwany onboarding ma sie powtorzyc po restarcie');

    await tapNext(tester, 'Zaczynamy');
    expect(prefs.getBool(onboardingCompletedKey), isTrue);
  });

  testWidgets('Zezwol pyta wtyczke i potwierdza przyznana zgode', (tester) async {
    final recorder = StubRecorder(granted: true);
    await pumpOnboarding(tester, recorder: recorder);
    await tapNext(tester, 'Dalej');

    expect(recorder.asked, 0, reason: 'systemowy dialog dopiero po tapnieciu, nie na wejsciu');

    await tester.tap(find.text('Zezwól'));
    await settleFrames(tester);

    expect(recorder.asked, 1);
    expect(find.text('Przyznany'), findsOneWidget);
    expect(find.text('Zezwól'), findsNothing);
  });

  testWidgets('odmowa podpowiada ustawienia systemu i pozwala ponowic', (tester) async {
    final recorder = StubRecorder(granted: false);
    await pumpOnboarding(tester, recorder: recorder);
    await tapNext(tester, 'Dalej');

    await tester.tap(find.text('Zezwól'));
    await settleFrames(tester);

    expect(find.text('Odmówiono. Dostęp włączysz w ustawieniach systemu.'), findsOneWidget);
    expect(find.text('Ponów'), findsOneWidget);
  });

  testWidgets('brak zgody nie blokuje przejscia dalej', (tester) async {
    final prefs = await pumpOnboarding(tester, recorder: StubRecorder(granted: false));

    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Zaczynamy');

    expect(prefs.getBool(onboardingCompletedKey), isTrue);
  });

  testWidgets('kafelek klucza konczy onboarding i otwiera Ustawienia', (tester) async {
    final prefs = await pumpOnboarding(tester);
    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Dalej');

    await tester.tap(find.text('Klucz API'));
    await settleFrames(tester);

    expect(prefs.getBool(onboardingCompletedKey), isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('podwojny tap na kafelku klucza otwiera Ustawienia raz', (tester) async {
    await pumpOnboarding(tester);
    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Dalej');

    // Dwa tapniecia w jednej porcji zdarzen wolaja onTap synchronicznie, jeszcze zanim
    // pierwsze wywolanie dojdzie do swojego awaita. Przez tester.tap tego nie odtworzymy:
    // await miedzy nimi przepuszcza mikrozadania i drugie tapniecie nie ma juz w co trafic.
    // Bez straznika re-entrancy oba wypchnelyby Ustawienia i user cofalby sie dwa razy.
    final tile = tester.widget<OnboardingCard>(find.byType(OnboardingCard));
    tile.onTap!();
    tile.onTap!();
    await settleFrames(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Sama obecnosc ekranu ustawien niczego nie dowodzi: Overlay buduje tylko trasy nad
    // ostatnia nieprzezroczysta, wiec druga kopia na stosie i tak byla niewidoczna.
    // Liczymy trasy jedynym sposobem, ktory widzi user — cofnieciem.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settleFrames(tester);

    expect(find.byType(SettingsScreen), findsNothing,
        reason: 'jeden back ma wrocic do onboardingu, a nie do drugich Ustawien');
  });

  // --- Straznik regresji (runda fix 1) ---
  // Reszta testow czyta flage przez stala onboardingCompletedKey, wiec podmiana jej WARTOSCI
  // (przy tej samej nazwie) przeszlaby caly suite na zielono, a onboarding wrocilby kazdemu
  // istniejacemu uzytkownikowi po aktualizacji. Ten test pilnuje litery zapisu na dysku.
  testWidgets('STRAZNIK: przejscie do konca zapisuje surowy klucz onboarding_completed',
      (tester) async {
    final prefs = await pumpOnboarding(tester);

    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Dalej');
    await tapNext(tester, 'Zaczynamy');

    expect(prefs.getBool('onboarding_completed'), isTrue,
        reason: 'literal klucza to format danych na dysku — przezywa aktualizacje aplikacji');
  });
}
