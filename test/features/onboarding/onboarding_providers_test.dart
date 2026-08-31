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
    test('fresh installation has no flag, so onboarding must be shown', () async {
      final container = await containerWith({});

      expect(container.read(onboardingCompletedProvider), isFalse);
    });

    test('stored flag skips onboarding', () async {
      final container = await containerWith({onboardingCompletedKey: true});

      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('complete() switches state immediately', () async {
      final container = await containerWith({});

      await container.read(onboardingCompletedProvider.notifier).complete();

      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('flag survives app restart', () async {
      final container = await containerWith({});
      await container.read(onboardingCompletedProvider.notifier).complete();

      // New container over same preferences simulates subsequent app launch.
      final prefs = await SharedPreferences.getInstance();
      final restarted =
          ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(restarted.dispose);

      expect(restarted.read(onboardingCompletedProvider), isTrue);
    });

    test('different value type in preferences does not crash launch', () async {
      final container = await containerWith({onboardingCompletedKey: 'yes'});

      expect(container.read(onboardingCompletedProvider), isFalse);
    });
  });
}
