import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/features/onboarding/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('onboardingCompletedProvider', () {
    test('swieza instalacja nie ma flagi, wiec onboarding jest do przejscia', () async {
      final container = await containerWith({});

      expect(container.read(onboardingCompletedProvider), isFalse);
    });

    test('zapisana flaga pomija onboarding', () async {
      final container = await containerWith({onboardingCompletedKey: true});

      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('complete() natychmiast przelacza stan', () async {
      final container = await containerWith({});

      await container.read(onboardingCompletedProvider.notifier).complete();

      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('flaga przezywa restart aplikacji', () async {
      final container = await containerWith({});
      await container.read(onboardingCompletedProvider.notifier).complete();

      // Nowy kontener nad tymi samymi preferencjami to symulacja kolejnego uruchomienia.
      final prefs = await SharedPreferences.getInstance();
      final restarted =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(restarted.dispose);

      expect(restarted.read(onboardingCompletedProvider), isTrue);
    });

    test('wartosc innego typu w preferencjach nie wywraca startu', () async {
      final container = await containerWith({onboardingCompletedKey: 'yes'});

      expect(container.read(onboardingCompletedProvider), isFalse);
    });
  });
}
