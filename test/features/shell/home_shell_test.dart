import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/app.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/features/library/library_screen.dart';
import 'package:mikro/features/recorder/recorder_controller.dart';
import 'package:mikro/features/recorder/recorder_screen.dart';
import 'package:mikro/features/shell/home_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_harness.dart';

class FakeRecorder implements MikroRecorder {
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

class FakeKeyStore implements KeyStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

/// Recording performs real disk operations, and `testWidgets` runs
/// in a fake-async zone where real I/O never finishes — production controller
/// would get stuck on directory creation. Recording mechanics are covered by recorder_controller_test;
/// here we only care about what the screen does after stopping.
class FakeRecorderController extends RecorderController {
  @override
  RecorderState build() => const RecorderState();

  @override
  Future<void> startRecording() async => state = const RecorderState(isRecording: true);

  @override
  Future<void> stopRecording() async => state = const RecorderState();
}

void main() {
  late ProviderContainer container;

  /// Mounts shell directly, skipping OnboardingGate — that has its own tests, and here
  /// it would only obscure navigation on first launch.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(412, 892),
    List<Override> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      baseDirProvider.overrideWithValue(Directory.systemTemp.createTempSync('mikro-shell')),
      databaseProvider.overrideWithValue(db),
      recorderProvider.overrideWithValue(FakeRecorder()),
      keyStoreProvider.overrideWithValue(FakeKeyStore()),
      ...extraOverrides,
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: localizedApp(const HomeShell()),
    ));
    await tester.pump();
  }

  /// Library subscribes to drift stream and IndexedStack builds every tab, so this
  /// subscription lives throughout the test. On teardown drift schedules a zero Timer
  /// to unregister it — pump() alone won't trigger it because virtual time needs to advance.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  int? shownTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  testWidgets('empty library CTA switches to Record', (tester) async {
    await mount(tester);
    container.read(homeTabProvider.notifier).select(HomeTab.library);
    await tester.pump();

    await tester.tap(find.text(plL10n.libraryRecordCta));
    await tester.pump();

    expect(container.read(homeTabProvider), HomeTab.recorder);
    expect(shownTab(tester), HomeTab.recorder);
    await settle(tester);
  });

  testWidgets('history icon on Record screen switches to Library', (tester) async {
    await mount(tester);

    await tester.tap(find.descendant(
      of: find.byType(RecorderScreen),
      matching: find.byIcon(Symbols.history_rounded),
    ));
    await tester.pump();

    expect(container.read(homeTabProvider), HomeTab.library);
    expect(shownTab(tester), HomeTab.library);
    await settle(tester);
  });

  testWidgets('snackbar after recording has View action leading to Library', (tester) async {
    await mount(tester, extraOverrides: [
      recorderControllerProvider.overrideWith(FakeRecorderController.new),
    ]);

    // Icon scaling in blob differs from navigation bar, but both use the same
    // Symbols.mic_rounded — narrowing to RecorderScreen filters out bar destinations.
    Finder inRecorder(IconData icon) => find.descendant(
          of: find.byType(RecorderScreen),
          matching: find.byIcon(icon),
        );

    /// Start and stop perform real disk operations, and during recording pulsing
    /// schedules frame after frame — pumpAndSettle would never return. We pump until
    /// condition is met, with a hard limit so inaction results in an assertion rather than hanging.
    Future<void> pumpUntil(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await tester.tap(inRecorder(Symbols.mic_rounded));
    await pumpUntil(inRecorder(Symbols.stop_rounded));
    expect(inRecorder(Symbols.stop_rounded), findsOneWidget,
        reason: 'without entering recording state there is nothing to stop');

    await tester.tap(inRecorder(Symbols.stop_rounded));
    await pumpUntil(find.text(plL10n.recorderSavedAction));
    expect(find.text(plL10n.recorderSavedAction), findsOneWidget,
        reason: 'mockup shows snackbar with action after saving recording');

    // After stopping recording pulsing no longer ticks, so settle is safe — and necessary
    // here: halfway through snackbar entrance animation the action is still off-screen and tapping
    // would hit empty space.
    await tester.pumpAndSettle();

    await tester.tap(find.text(plL10n.recorderSavedAction));
    await tester.pump();

    expect(container.read(homeTabProvider), HomeTab.library);
    expect(shownTab(tester), HomeTab.library);
    await settle(tester);
  });

  testWidgets('narrow screen keeps bottom bar', (tester) async {
    await mount(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await settle(tester);
  });

  testWidgets('wide screen gets rail instead of bottom bar', (tester) async {
    await mount(tester, size: const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await settle(tester);
  });

  testWidgets('navigation rail threshold is set at 840 dp', (tester) async {
    // Mockup shows rail at 1280 px without specifying threshold, so 840 dp is
    // a design decision, not a transcription — all the more reason to pin it.
    await mount(tester, size: const Size(839, 800));
    expect(find.byType(NavigationBar), findsOneWidget,
        reason: 'one dp below threshold navigation stays at bottom');
    expect(find.byType(NavigationRail), findsNothing);
    await settle(tester);

    await mount(tester, size: const Size(840, 800));
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'threshold is inclusive from above');
    expect(find.byType(NavigationBar), findsNothing);
    await settle(tester);
  });

  testWidgets('rail switches tabs same as bottom bar', (tester) async {
    await mount(tester, size: const Size(1280, 800));

    await tester.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(plL10n.navLibrary),
    ));
    await tester.pumpAndSettle();

    expect(container.read(homeTabProvider), HomeTab.library);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await settle(tester);
  });
}
