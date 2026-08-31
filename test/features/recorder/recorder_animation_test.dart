import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/features/recorder/recorder_controller.dart';
import 'package:mikro/features/recorder/recorder_screen.dart';

import '../../support/l10n_harness.dart';

/// Fake controller: test concerns ticker lifecycle on screen rather than recording,
/// so state is supplied directly instead of dragging microphone, database and pipeline.
class _FakeController extends RecorderController {
  @override
  RecorderState build() => const RecorderState();

  void emit(RecorderState next) => state = next;
}

void main() {
  group('phaseAt', () {
    // Mockup elements whose period DOES NOT divide the common clock period (6 s): outer
    // ring and bar #1. These were experiencing phase jumps at every wrap.
    const nonDividing = <double>[2.4, 0.9];

    test('phase is continuous when passing through 6 seconds', () {
      for (final period in nonDividing) {
        final before = phaseAt(5.999, period);
        final after = phaseAt(6.001, period);
        // Forward delta, robust to normal 1.0 wrap in this window.
        final delta = (after - before + 1.0) % 1.0;
        expect(delta, closeTo(0.002 / period, 1e-9),
            reason: 'period $period s: phase must advance by 2 ms of time, not jump by half a cycle');
      }
    });

    test('phase is continuous also across multiple wraps and with delay', () {
      for (final moment in <double>[6, 12, 18]) {
        for (final period in nonDividing) {
          final delta =
              (phaseAt(moment + 0.001, period, -0.2) - phaseAt(moment - 0.001, period, -0.2) + 1.0) %
                  1.0;
          expect(delta, closeTo(0.002 / period, 1e-9),
              reason: 'period $period s at time $moment s');
        }
      }
    });

    test('phase increases linearly with time and wraps at full period', () {
      expect(phaseAt(0, 2.4), closeTo(0, 1e-12));
      expect(phaseAt(0.6, 2.4), closeTo(0.25, 1e-12));
      expect(phaseAt(1.2, 2.4), closeTo(0.5, 1e-12));
      expect(phaseAt(2.4, 2.4), closeTo(0, 1e-12), reason: 'full period returns to zero');
      expect(phaseAt(3.0, 2.4), closeTo(0.25, 1e-12), reason: 'second cycle is a copy of first');
    });

    test('delay shifts phase forward, matching negative delay from mockup', () {
      expect(phaseAt(0, 0.9, -0.2), closeTo(0.2 / 0.9, 1e-12));
      expect(phaseAt(0.2, 0.9, -0.2), closeTo(0.4 / 0.9, 1e-12));
    });
  });

  group('ticker lifecycle', () {
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

    // Active Ticker holds a registered transient callback for every frame. Counter from
    // binding is thus a direct, non-flaky measure of "is anything animating" —
    // cheaper and more reliable than measuring pumpAndSettle duration.
    testWidgets('idle state does not animate', (tester) async {
      await mount(tester);

      expect(tester.binding.transientCallbackCount, 0,
          reason: 'IndexedStack keeps this screen alive on every tab — pulsing outside recording '
              'would force computing nine cosines 60 times per second throughout app lifecycle');
    });

    testWidgets('ticker starts on recording begin and stops on recording stop', (tester) async {
      final controller = await mount(tester);

      controller.emit(const RecorderState(isRecording: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0),
          reason: 'during recording pulse must actually run');

      controller.emit(const RecorderState());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'recording stop halts ticker rather than merely hiding animations');
    });
  });
}
