import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/features/shell/home_tab.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('powloka startuje na zakladce Nagrywaj', () {
    expect(container.read(homeTabProvider), HomeTab.recorder);
  });

  test('select przestawia zakladke', () {
    container.read(homeTabProvider.notifier).select(HomeTab.library);
    expect(container.read(homeTabProvider), HomeTab.library);

    container.read(homeTabProvider.notifier).select(HomeTab.settings);
    expect(container.read(homeTabProvider), HomeTab.settings);
  });

  test('indeks spoza zakresu wysypuje sie glosno, zamiast dac pusty IndexedStack', () {
    final controller = container.read(homeTabProvider.notifier);
    expect(() => controller.select(HomeTab.count), throwsA(isA<AssertionError>()));
    expect(() => controller.select(-1), throwsA(isA<AssertionError>()));
    expect(container.read(homeTabProvider), HomeTab.recorder,
        reason: 'odrzucony indeks nie moze zostawic powloki w polowicznym stanie');
  });
}
