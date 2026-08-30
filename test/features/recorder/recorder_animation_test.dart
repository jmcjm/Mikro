import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/features/recorder/recorder_controller.dart';
import 'package:mikro/features/recorder/recorder_screen.dart';

import '../../support/l10n_harness.dart';

/// Podstawiony kontroler: test dotyczy cyklu zycia tickera na ekranie, a nie nagrywania,
/// wiec stan podajemy wprost, zamiast ciagnac za soba mikrofon, baze i pipeline.
class _FakeController extends RecorderController {
  @override
  RecorderState build() => const RecorderState();

  void emit(RecorderState next) => state = next;
}

void main() {
  group('phaseAt', () {
    // Elementy makiety, ktorych okres NIE dzieli okresu wspolnego zegara (6 s): pierscien
    // zewnetrzny i slupek nr 1. To one lapaly skok fazy przy kazdym zawinieciu.
    const nieDzielace = <double>[2.4, 0.9];

    test('faza jest ciagla przy przejsciu przez 6 sekund', () {
      for (final okres in nieDzielace) {
        final przed = phaseAt(5.999, okres);
        final po = phaseAt(6.001, okres);
        // Przyrost do przodu, odporny na normalne przekroczenie 1.0 w tym oknie.
        final przyrost = (po - przed + 1.0) % 1.0;
        expect(przyrost, closeTo(0.002 / okres, 1e-9),
            reason: 'okres $okres s: faza ma przyrastac o 2 ms czasu, nie skakac o pol cyklu');
      }
    });

    test('faza jest ciagla takze przy kolejnych zawinieciach i z opoznieniem', () {
      for (final chwila in <double>[6, 12, 18]) {
        for (final okres in nieDzielace) {
          final przyrost =
              (phaseAt(chwila + 0.001, okres, -0.2) - phaseAt(chwila - 0.001, okres, -0.2) + 1.0) %
                  1.0;
          expect(przyrost, closeTo(0.002 / okres, 1e-9),
              reason: 'okres $okres s w chwili $chwila s');
        }
      }
    });

    test('faza rosnie liniowo z czasem i zawija sie na pelnym okresie', () {
      expect(phaseAt(0, 2.4), closeTo(0, 1e-12));
      expect(phaseAt(0.6, 2.4), closeTo(0.25, 1e-12));
      expect(phaseAt(1.2, 2.4), closeTo(0.5, 1e-12));
      expect(phaseAt(2.4, 2.4), closeTo(0, 1e-12), reason: 'pelny okres wraca do zera');
      expect(phaseAt(3.0, 2.4), closeTo(0.25, 1e-12), reason: 'drugi cykl jest kopia pierwszego');
    });

    test('opoznienie przesuwa faze do przodu, zgodnie z ujemnymi delay z makiety', () {
      expect(phaseAt(0, 0.9, -0.2), closeTo(0.2 / 0.9, 1e-12));
      expect(phaseAt(0.2, 0.9, -0.2), closeTo(0.4 / 0.9, 1e-12));
    });
  });

  group('cykl zycia tickera', () {
    Future<_FakeController> mount(WidgetTester tester) async {
      late _FakeController controller;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          recorderControllerProvider.overrideWith(() => controller = _FakeController()),
        ],
        child: localizedApp(const RecorderScreen()),
      ));
      await tester.pumpAndSettle();
      return controller;
    }

    // Aktywny Ticker trzyma zarejestrowany transient callback na kazda klatke. Licznik z
    // bindinga jest wiec bezposrednim, nieflakujacym pomiarem "czy cos sie animuje" —
    // taniej i pewniej niz mierzenie czasu pumpAndSettle.
    testWidgets('w spoczynku nic sie nie animuje', (tester) async {
      await mount(tester);

      expect(tester.binding.transientCallbackCount, 0,
          reason: 'IndexedStack trzyma ten ekran zywy na kazdej zakladce — puls poza nagraniem '
              'kazalby liczyc dziewiec cosinusow 60 razy na sekunde przez cale zycie aplikacji');
    });

    testWidgets('ticker rusza na start nagrania i milknie po stopie', (tester) async {
      final controller = await mount(tester);

      controller.emit(const RecorderState(isRecording: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0),
          reason: 'w trakcie nagrania puls ma faktycznie chodzic');

      controller.emit(const RecorderState());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'stop nagrania zatrzymuje ticker, a nie tylko chowa animacje');
    });
  });
}
