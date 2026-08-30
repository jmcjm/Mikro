import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/features/onboarding/onboarding_gate.dart';
import 'package:mikro/features/onboarding/onboarding_providers.dart';
import 'package:mikro/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StubRecorder implements MikroRecorder {
  @override
  String get fileExtension => 'm4a';
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<double> amplitude() => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

Future<ProviderContainer> pumpGate(WidgetTester tester, Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    recorderProvider.overrideWithValue(StubRecorder()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: OnboardingGate(child: Text('powloka', textDirection: TextDirection.ltr)),
    ),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('pierwsze uruchomienie ląduje w onboardingu', (tester) async {
    await pumpGate(tester, {});

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('powloka'), findsNothing);
  });

  testWidgets('kolejne uruchomienie idzie prosto do powloki', (tester) async {
    await pumpGate(tester, {onboardingCompletedKey: true});

    expect(find.text('powloka'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('zakonczenie onboardingu przelacza gate bez restartu', (tester) async {
    final container = await pumpGate(tester, {});

    await container.read(onboardingCompletedProvider.notifier).complete();
    await tester.pump();

    expect(find.text('powloka'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
