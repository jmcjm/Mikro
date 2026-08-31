import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/waveform.dart';
import 'package:mikro/features/library/playback.dart';

void main() {
  group('nextPlaybackRate', () {
    test('cycle follows mockup order and loops back to 1.0', () {
      expect(nextPlaybackRate(1.0), 1.25);
      expect(nextPlaybackRate(1.25), 1.5);
      expect(nextPlaybackRate(1.5), 2.0);
      expect(nextPlaybackRate(2.0), 1.0);
    });

    test('value outside cycle returns to its beginning', () {
      // Cannot be set from the screen today, but the function must not return something
      // that the pill cannot display.
      expect(nextPlaybackRate(1.75), 1.0);
    });

    test('cycle closes on every value from the list', () {
      var rate = kPlaybackRates.first;
      final seen = <double>[];
      for (var i = 0; i < kPlaybackRates.length; i++) {
        seen.add(rate);
        rate = nextPlaybackRate(rate);
      }
      expect(seen, kPlaybackRates);
      expect(rate, kPlaybackRates.first, reason: 'full turn returns to start');
    });
  });

  group('skipTarget', () {
    const total = Duration(seconds: 100);

    test('skip forward and backward shifts by given step', () {
      expect(skipTarget(const Duration(seconds: 30), kSkipStep, total),
          const Duration(seconds: 40));
      expect(skipTarget(const Duration(seconds: 30), -kSkipStep, total),
          const Duration(seconds: 20));
    });

    test('bottom and top are clamped to recording', () {
      expect(skipTarget(const Duration(seconds: 4), -kSkipStep, total), Duration.zero);
      expect(skipTarget(const Duration(seconds: 95), kSkipStep, total), total);
    });

    test('position outside recording also ends in range', () {
      expect(skipTarget(const Duration(seconds: 500), kSkipStep, total), total);
      expect(skipTarget(const Duration(seconds: -5), -kSkipStep, total), Duration.zero);
    });

    test('recording with unknown duration does not drift', () {
      expect(skipTarget(const Duration(seconds: 30), kSkipStep, Duration.zero), Duration.zero);
    });

    test('step is 10 s in both directions', () {
      expect(kSkipStep, const Duration(seconds: 10));
    });
  });

  group('playedBars', () {
    test('beginning and end of recording are extreme divisions', () {
      expect(playedBars(count: 44, position: Duration.zero, total: const Duration(seconds: 44)),
          0);
      expect(
          playedBars(
              count: 44,
              position: const Duration(seconds: 44),
              total: const Duration(seconds: 44)),
          44);
    });

    test('division follows mockup formula: bar i is played when i/count < progress', () {
      // 34% from mockup: bars 0..14 are played because 14/44 = 0.318 < 0.34, while 15/44 = 0.341 is not.
      expect(
          playedBars(
              count: 44,
              position: const Duration(milliseconds: 34000),
              total: const Duration(milliseconds: 100000)),
          15);
    });

    test('bar boundary belongs to unplayed', () {
      // Exactly 10/44 of recording: bar 10 starts at this point, so remains empty.
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
          reason: 'millisecond past boundary illuminates next bar');
    });

    test('position beyond recording does not exceed bar count', () {
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

    test('without duration or without bars there is nothing to divide', () {
      expect(playedBars(count: 44, position: const Duration(seconds: 5), total: Duration.zero), 0);
      expect(playedBars(count: 0, position: const Duration(seconds: 5), total: const Duration(seconds: 44)), 0);
    });
  });

  group('positionAt', () {
    const total = Duration(seconds: 200);

    test('fraction of width maps to position in recording', () {
      expect(positionAt(dx: 0, width: 400, total: total), Duration.zero);
      expect(positionAt(dx: 200, width: 400, total: total), const Duration(seconds: 100));
      expect(positionAt(dx: 400, width: 400, total: total), total);
    });

    test('touch outside bar lands on its edge', () {
      expect(positionAt(dx: -30, width: 400, total: total), Duration.zero);
      expect(positionAt(dx: 900, width: 400, total: total), total);
    });

    test('zero-width bar does not divide by zero', () {
      expect(positionAt(dx: 10, width: 0, total: total), Duration.zero);
    });
  });

  group('interpolatePosition', () {
    const total = Duration(seconds: 100);

    test('between events position increases by elapsed time', () {
      expect(
          interpolatePosition(
              base: const Duration(seconds: 10),
              elapsed: const Duration(milliseconds: 500),
              rate: 1.0,
              total: total),
          const Duration(milliseconds: 10500));
    });

    test('playback rate scales elapsed time', () {
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

    test('interpolation does not overshoot end of recording', () {
      expect(
          interpolatePosition(
              base: const Duration(seconds: 99),
              elapsed: const Duration(seconds: 30),
              rate: 2.0,
              total: total),
          total);
    });

    test('recording with unknown duration has no upper bound, but has lower bound', () {
      // Zero duration means "not yet known" — clamping to zero would halt
      // cursor at start instead of letting it advance.
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

    test('resolution goes below a single frame', () {
      // A 60 Hz frame is ~16.7 ms. Computing on whole milliseconds of elapsed
      // is sufficient, but rounding must not lose a full frame.
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
    test('forward event takes the lead', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 10), event: const Duration(milliseconds: 10200)),
          const Duration(milliseconds: 10200));
    });

    test('slight backward jump does not jerk cursor', () {
      // Event slightly behind interpolation is normal; rewinding cursor by tens of
      // milliseconds looks like jitter.
      expect(
          reconcilePosition(
              shown: const Duration(milliseconds: 10200), event: const Duration(seconds: 10)),
          const Duration(milliseconds: 10200));
    });

    test('large backward jump is real and cursor follows immediately', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 100), event: const Duration(seconds: 3)),
          const Duration(seconds: 3));
    });

    test('large forward jump is also immediate', () {
      expect(
          reconcilePosition(
              shown: const Duration(seconds: 3), event: const Duration(seconds: 100)),
          const Duration(seconds: 100));
    });

    test('smoothing threshold is half a second by default', () {
      expect(kPositionSnap, const Duration(milliseconds: 500));
      // Right on the boundary we still smooth, only above do we snap.
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

  group('dancingBarLevel', () {
    test('bar floats in a narrow band BELOW its true height', () {
      for (var index = 0; index < kWaveformBuckets; index++) {
        for (var step = 0; step < 120; step++) {
          final value =
              dancingBarLevel(level: 0.8, elapsedSeconds: step * 0.05, index: index);
          expect(value, greaterThanOrEqualTo(0.8 * (1 - kBarDanceDepth) - 1e-9),
              reason: 'wider band turns waveform into equalizer');
          expect(value, lessThanOrEqualTo(0.8 + 1e-9),
              reason: 'above its own height bar would misrepresent recording');
        }
      }
    });

    test('GUARD: bar ordering matches envelope in EVERY frame', () {
      // Not "on average": frozen animation frame should be almost indistinguishable from
      // static graph, so louder part must ALWAYS be taller. This test fails
      // when breath band widens enough for quiet bar at peak to exceed loud bar at trough —
      // exactly what user saw in the first version.
      const levels = [1.0, 0.75, 0.5, 0.25];
      for (var step = 0; step < 400; step++) {
        final t = step * 0.031;
        final heights = [
          for (var i = 0; i < levels.length; i++)
            dancingBarLevel(level: levels[i], elapsedSeconds: t, index: i),
        ];
        for (var i = 1; i < heights.length; i++) {
          expect(heights[i - 1], greaterThan(heights[i]),
              reason: 'at time $t bar $i exceeded louder neighbor');
        }
      }
    });

    test('dance scales the bar instead of shifting it to another height', () {
      for (var step = 0; step < 40; step++) {
        final t = step * 0.07;
        expect(dancingBarLevel(level: 0.9, elapsedSeconds: t, index: 3) / 0.9,
            closeTo(dancingBarLevel(level: 0.3, elapsedSeconds: t, index: 3) / 0.3, 1e-9));
      }
    });

    test('bars do not breathe uniformly: neighbors have different phases', () {
      final atMoment = [
        for (var i = 0; i < 12; i++)
          dancingBarLevel(level: 1, elapsedSeconds: 0.3, index: i),
      ];
      expect(atMoment.toSet().length, greaterThan(6),
          reason: 'if all bars had the same phase, the band would pulse as a single block');
    });

    test('period-delay pair does not repeat across bars', () {
      final pairs = <String>{};
      for (var i = 0; i < kWaveformBuckets; i++) {
        pairs.add('${kBarDanceSeconds[i % kBarDanceSeconds.length]}'
            '/${kBarDanceDelays[i % kBarDanceDelays.length]}');
      }
      expect(pairs.length, kWaveformBuckets,
          reason: 'repeated pair creates visible pattern in band');
    });

    test('breath is gentle: full cycle lasts over two seconds', () {
      expect(kBarDanceSeconds.reduce((a, b) => a < b ? a : b), greaterThan(2.0));
    });

    test('cycle closes smoothly without jump', () {
      // Mockup has `@keyframes bar { 0%,100% { scaleY(.25) } 50% { scaleY(1) } }`, i.e.
      // triangle: on cycle wrap bar does NOT drop abruptly.
      final period = kBarDanceSeconds[0];
      final before = dancingBarLevel(level: 1, elapsedSeconds: period - 0.001, index: 0);
      final after = dancingBarLevel(level: 1, elapsedSeconds: period + 0.001, index: 0);
      expect((after - before).abs(), lessThan(0.005));
    });

    test('half cycle is peak, start and end are trough', () {
      // Bar 3: period 2.4 s and delay 0.0 s, easiest to calculate.
      expect(dancingBarLevel(level: 1, elapsedSeconds: 0.0, index: 3),
          closeTo(1 - kBarDanceDepth, 1e-9));
      expect(dancingBarLevel(level: 1, elapsedSeconds: 1.2, index: 3), closeTo(1.0, 1e-9));
      expect(dancingBarLevel(level: 1, elapsedSeconds: 2.4, index: 3),
          closeTo(1 - kBarDanceDepth, 1e-9));
    });

    test('silence remains silence', () {
      expect(dancingBarLevel(level: 0, elapsedSeconds: 0.4, index: 5), 0);
    });
  });
}
