import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/util/format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
  test('formatDateTime', () {
    expect(formatDateTime(DateTime(2026, 8, 29, 7, 5)), '2026-08-29 07:05');
  });
}
