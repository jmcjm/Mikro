import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/onboarding/onboarding_providers.dart';
import 'package:mikro/features/onboarding/onboarding_screen.dart';
import 'package:mikro/features/onboarding/onboarding_widgets.dart';
import 'package:mikro/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_harness.dart';

/// Backs the permission step: recording plugin itself shows system dialog, so test
/// only stubs its response and counts requests.
class StubRecorder implements MikroRecorder {
  StubRecorder({required this.granted});

  final bool granted;
  var asked = 0;

  @override
  String get fileExtension => 'm4a';
  @override
  Future<bool> hasPermission() async {
    asked++;
    return granted;
  }

  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<double> amplitude() => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

// Settings screen reads configuration in initState — without stubbing key store test would hit
// flutter_secure_storage platform channel.
class FakeKeyStore implements KeyStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

/// Welcome step animates in loop (blob from design), so pumpAndSettle would never return.
/// We advance virtual time explicitly below.
Future<void> settleFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<SharedPreferences> pumpOnboarding(WidgetTester tester, {StubRecorder? recorder}) async {
  // Default test window (800x600) is shorter than phone for which design was drawn,
  // so cards would lie below the bottom edge. We test on mockup dimensions.
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      recorderProvider.overrideWithValue(recorder ?? StubRecorder(granted: true)),
      keyStoreProvider.overrideWithValue(FakeKeyStore()),
    ],
    child: localizedApp(const OnboardingScreen()),
  ));
  await tester.pump();
  return prefs;
}

Future<void> tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleFrames(tester);
}

void main() {
  testWidgets('first step greets with design headline', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text(plL10n.onboardingWelcomeHeadline), findsOneWidget);
    expect(find.text(plL10n.onboardingNext), findsOneWidget);
  });

  testWidgets('three steps, and flag is only set by the last one', (tester) async {
    final prefs = await pumpOnboarding(tester);

    await tapNext(tester, plL10n.onboardingNext);
    expect(find.text(plL10n.onboardingMicTitle), findsOneWidget);
    expect(find.text(plL10n.onboardingMicSubtitle), findsOneWidget);

    await tapNext(tester, plL10n.onboardingNext);
    expect(find.text(plL10n.onboardingProviderTitle), findsOneWidget);
    expect(find.text(plL10n.onboardingProviderSubtitle), findsOneWidget);
    expect(find.text(plL10n.onboardingNext), findsNothing);
    expect(prefs.get(onboardingCompletedKey), isNull,
        reason: 'interrupted onboarding must be repeated after restart');

    await tapNext(tester, plL10n.onboardingStart);
    expect(prefs.getBool(onboardingCompletedKey), isTrue);
  });

  testWidgets('Allow queries plugin and confirms granted permission', (tester) async {
    final recorder = StubRecorder(granted: true);
    await pumpOnboarding(tester, recorder: recorder);
    await tapNext(tester, plL10n.onboardingNext);

    expect(recorder.asked, 0, reason: 'system dialog only after tapping, not upon entry');

    await tester.tap(find.text(plL10n.onboardingMicAllow));
    await settleFrames(tester);

    expect(recorder.asked, 1);
    expect(find.text(plL10n.onboardingMicGranted), findsOneWidget);
    expect(find.text(plL10n.onboardingMicAllow), findsNothing);
  });

  testWidgets('denial suggests system settings and allows retry', (tester) async {
    final recorder = StubRecorder(granted: false);
    await pumpOnboarding(tester, recorder: recorder);
    await tapNext(tester, plL10n.onboardingNext);

    await tester.tap(find.text(plL10n.onboardingMicAllow));
    await settleFrames(tester);

    expect(find.text(plL10n.onboardingMicDenied), findsOneWidget);
    expect(find.text(plL10n.onboardingMicRetry), findsOneWidget);
  });

  testWidgets('lack of permission does not block progressing further', (tester) async {
    final prefs = await pumpOnboarding(tester, recorder: StubRecorder(granted: false));

    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingStart);

    expect(prefs.getBool(onboardingCompletedKey), isTrue);
  });

  testWidgets('API key card completes onboarding and opens Settings', (tester) async {
    final prefs = await pumpOnboarding(tester);
    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingNext);

    await tester.tap(find.text(plL10n.onboardingProviderTitle));
    await settleFrames(tester);

    expect(prefs.getBool(onboardingCompletedKey), isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('double tap on API key card opens Settings once', (tester) async {
    await pumpOnboarding(tester);
    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingNext);

    // Two taps in a single event batch call onTap synchronously, before
    // first invocation reaches its await. We cannot reproduce this via tester.tap:
    // await between them yields to microtasks and second tap has nothing left to hit.
    // Without re-entrancy guard both would push Settings and user would have to pop twice.
    final tile = tester.widget<OnboardingCard>(find.byType(OnboardingCard));
    tile.onTap!();
    tile.onTap!();
    await settleFrames(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Merely checking SettingsScreen presence proves nothing: Overlay only builds routes above
    // the latest opaque route, so second copy on stack was invisible anyway.
    // We count routes the only user-observable way — via back navigation.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settleFrames(tester);

    expect(find.byType(SettingsScreen), findsNothing,
        reason: 'a single back navigation must return to onboarding rather than a second Settings screen');
  });

  // --- Regression guard (fix round 1) ---
  // Other tests read the flag via onboardingCompletedKey constant, so changing its VALUE
  // (while keeping the constant name) would keep whole suite green, and onboarding would return to every
  // existing user after update. This test guards the exact on-disk literal.
  testWidgets('GUARD: completing onboarding writes raw key onboarding_completed',
      (tester) async {
    final prefs = await pumpOnboarding(tester);

    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingNext);
    await tapNext(tester, plL10n.onboardingStart);

    expect(prefs.getBool('onboarding_completed'), isTrue,
        reason: 'key literal is on-disk data format — survives app updates');
  });
}
