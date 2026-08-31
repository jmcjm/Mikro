import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/waveform.dart';

void main() {
  group('reduceToBuckets', () {
    test('divides samples evenly and takes the peak of each bucket', () {
      // 8 samples -> 4 buckets, 2 samples per bucket. Values chosen such that each
      // bucket has a different peak, so an off-by-one boundary error changes the result immediately.
      final buckets = reduceToBuckets(
        [0.1, 0.2, 0.9, 0.3, 0.4, 0.5, 0.6, 1.0],
        buckets: 4,
      );
      expect(buckets, [0.2, 0.9, 0.5, 1.0]);
    });

    test('last sample lands in the last bucket', () {
      // Guard against off-by-one at the upper bound: peak is at the very end of the input.
      final buckets = reduceToBuckets([0.1, 0.1, 0.1, 0.1, 0.1, 0.87], buckets: 3);
      expect(buckets.last, 0.87);
    });

    test('first sample lands in the first bucket', () {
      // Guard against off-by-one at the lower bound.
      final buckets = reduceToBuckets([0.93, 0.1, 0.1, 0.1, 0.1, 0.1], buckets: 3);
      expect(buckets.first, 0.93);
    });

    test('returns exactly the specified number of buckets with uneven division', () {
      final buckets = reduceToBuckets(List.filled(101, 0.5), buckets: kWaveformBuckets);
      expect(buckets, hasLength(kWaveformBuckets));
      expect(buckets.every((b) => b == 0.5), isTrue);
    });

    test('fewer samples than buckets: each bucket gets the nearest sample', () {
      // A short recording must not generate gaps, because empty buckets would look
      // like silence that did not occur.
      final buckets = reduceToBuckets([0.2, 0.8, 0.5], buckets: 6);
      expect(buckets, [0.2, 0.2, 0.8, 0.8, 0.5, 0.5]);
    });

    test('no samples yields empty list', () {
      expect(reduceToBuckets([], buckets: kWaveformBuckets), isEmpty);
    });

    test('out-of-range values are clamped to 0..1', () {
      expect(reduceToBuckets([-3.0, 2.5], buckets: 2), [0.0, 1.0]);
    });

    test('default bucket count matches the mockup', () {
      expect(kWaveformBuckets, 44);
      expect(reduceToBuckets(List.filled(500, 0.3)), hasLength(44));
    });
  });

  group('encoding', () {
    test('round trip preserves shape', () {
      final buckets = reduceToBuckets([0.125, 0.5, 0.875, 1.0], buckets: 4);
      expect(decodeWaveform(encodeWaveform(buckets)), buckets);
    });

    test('serialization truncates samples to three decimal places', () {
      // Database column has no reason to bloat with digits that a 56 px bar will not show.
      expect(encodeWaveform([1 / 3]), '[0.333]');
    });

    test('missing record yields null', () {
      expect(decodeWaveform(null), isNull);
      expect(decodeWaveform(''), isNull);
    });

    test('garbage in column yields null instead of exception', () {
      expect(decodeWaveform('nie-json'), isNull);
      expect(decodeWaveform('{"a":1}'), isNull);
      expect(decodeWaveform('[]'), isNull);
      expect(decodeWaveform('["a","b"]'), isNull);
    });

    test('deserialization clamps out-of-range values', () {
      expect(decodeWaveform('[-1, 0.5, 4]'), [0.0, 0.5, 1.0]);
    });
  });
}
