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
  group('formatPlaybackRate', () {
    test('polski separator dziesietny to przecinek', () {
      expect(formatPlaybackRate(1.0, locale: 'pl'), '1,0');
      expect(formatPlaybackRate(1.25, locale: 'pl'), '1,25');
      expect(formatPlaybackRate(1.5, locale: 'pl'), '1,5');
      expect(formatPlaybackRate(2.0, locale: 'pl'), '2,0');
    });

    test('angielski separator dziesietny to kropka', () {
      expect(formatPlaybackRate(1.0, locale: 'en'), '1.0');
      expect(formatPlaybackRate(1.25, locale: 'en'), '1.25');
      expect(formatPlaybackRate(1.5, locale: 'en'), '1.5');
      expect(formatPlaybackRate(2.0, locale: 'en'), '2.0');
    });

    test('zawsze jedna cyfra po separatorze, najwyzej dwie', () {
      // Bez minimum "1,0" schudloby do "1", a pigulka skakalaby na szerokosci przy kazdym
      // przelaczeniu; bez maksimum 1,25 rozlazloby sie na cyfry, ktorych nikt nie potrzebuje.
      expect(formatPlaybackRate(3.0, locale: 'pl'), '3,0');
      expect(formatPlaybackRate(1.125, locale: 'pl'), '1,13');
    });
  });
}
