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

/// Nagrywanie przechodzi przez prawdziwe operacje na dysku, a `testWidgets` biegnie
/// w strefie fake-async, w ktorej realne I/O nigdy sie nie konczy — kontroler z produkcji
/// utknalby na tworzeniu katalogu. Mechanike nagrywania pokrywa recorder_controller_test;
/// tutaj chodzi wylacznie o to, co ekran robi po zatrzymaniu.
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

  /// Montuje sama powloke, z pominieciem OnboardingGate — ten ma wlasne testy, a tutaj
  /// tylko zaslanialby nawigacje przy pierwszym uruchomieniu.
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
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.pump();
  }

  /// Biblioteka subskrybuje strumien drifta, a IndexedStack buduje kazda zakladke, wiec ta
  /// subskrypcja zyje przez caly test. Przy rozbiorce drift planuje zerowy Timer na jej
  /// wyrejestrowanie — samo pump() go nie odpali, bo czas wirtualny musi ruszyc.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  int? shownTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  testWidgets('CTA pustej biblioteki przelacza na Nagrywaj', (tester) async {
    await mount(tester);
    container.read(homeTabProvider.notifier).select(HomeTab.library);
    await tester.pump();

    await tester.tap(find.text('Nagraj pierwszą notatkę'));
    await tester.pump();

    expect(container.read(homeTabProvider), HomeTab.recorder);
    expect(shownTab(tester), HomeTab.recorder);
    await settle(tester);
  });

  testWidgets('ikona historii na ekranie Nagrywaj przelacza na Biblioteke', (tester) async {
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

  testWidgets('snackbar po nagraniu ma akcje Pokaz prowadzaca do Biblioteki', (tester) async {
    await mount(tester, extraOverrides: [
      recorderControllerProvider.overrideWith(FakeRecorderController.new),
    ]);

    // Skalowanie ikony w blobie jest inne niz w pasku nawigacji, ale obie to ten sam
    // Symbols.mic_rounded — zawezenie do RecorderScreen odsiewa destynacje paska.
    Finder inRecorder(IconData icon) => find.descendant(
          of: find.byType(RecorderScreen),
          matching: find.byIcon(icon),
        );

    /// Start i stop przechodza przez prawdziwe operacje na dysku, a w trakcie nagrania puls
    /// planuje klatke za klatka — pumpAndSettle nigdy by stad nie wrocil. Pompujemy wiec do
    /// skutku, z twardym limitem, zeby brak reakcji konczyl sie asercja, a nie zawieszeniem.
    Future<void> pumpUntil(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await tester.tap(inRecorder(Symbols.mic_rounded));
    await pumpUntil(inRecorder(Symbols.stop_rounded));
    expect(inRecorder(Symbols.stop_rounded), findsOneWidget,
        reason: 'bez wejscia w stan nagrywania nie ma czego zatrzymywac');

    await tester.tap(inRecorder(Symbols.stop_rounded));
    await pumpUntil(find.text('Pokaż'));
    expect(find.text('Pokaż'), findsOneWidget,
        reason: 'makieta pokazuje snackbar z akcja po zapisaniu nagrania');

    // Po zatrzymaniu nagrania puls juz nie tyka, wiec settle jest bezpieczne — a jest tu
    // konieczne: w polowie animacji wjazdu snackbara akcja stoi jeszcze poza kadrem i stuk
    // trafialby w pustke.
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pokaż'));
    await tester.pump();

    expect(container.read(homeTabProvider), HomeTab.library);
    expect(shownTab(tester), HomeTab.library);
    await settle(tester);
  });

  testWidgets('waski ekran zostaje przy dolnym pasku', (tester) async {
    await mount(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await settle(tester);
  });

  testWidgets('szeroki ekran dostaje rail zamiast dolnego paska', (tester) async {
    await mount(tester, size: const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await settle(tester);
  });

  testWidgets('prog nawigacji bocznej stoi na 840 dp', (tester) async {
    // Makieta pokazuje rail na 1280 px i nie podaje wlasnego progu, wiec 840 dp jest
    // decyzja, nie odczytem — tym bardziej ma byc przypiete.
    await mount(tester, size: const Size(839, 800));
    expect(find.byType(NavigationBar), findsOneWidget,
        reason: 'jeden dp ponizej progu nawigacja zostaje na dole');
    expect(find.byType(NavigationRail), findsNothing);
    await settle(tester);

    await mount(tester, size: const Size(840, 800));
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'prog jest domkniety od gory');
    expect(find.byType(NavigationBar), findsNothing);
    await settle(tester);
  });

  testWidgets('rail przelacza zakladki tak samo jak dolny pasek', (tester) async {
    await mount(tester, size: const Size(1280, 800));

    await tester.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Biblioteka'),
    ));
    await tester.pumpAndSettle();

    expect(container.read(homeTabProvider), HomeTab.library);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await settle(tester);
  });
}
