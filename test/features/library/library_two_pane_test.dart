import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/theme/app_theme.dart';
import 'package:mikro/features/library/library_screen.dart';
import 'package:mikro/features/library/recording_detail_screen.dart';
import 'package:mikro/features/library/selected_recording.dart';

import '../../support/l10n_harness.dart';

/// Liczy trasy dolozone PO starcie aplikacji. Trasa startowa przychodzi z `previousRoute`
/// rownym null i nie jest tu zadnym otwarciem szczegolow.
class RouteCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  late AppDatabase db;
  late Directory audioRoot;
  late ProviderContainer container;
  late RouteCounter routes;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Kasowanie nagrania usuwa KATALOG NADRZEDNY pliku audio. Przy sciezce w rodzaju
    // /tmp/a.m4a skasowaloby to cale /tmp, wiec kazde nagranie dostaje wlasny katalog
    // w swiezym tymczasowym korzeniu.
    audioRoot = Directory.systemTemp.createTempSync('mikro-two-pane');
  });
  tearDown(() {
    db.close();
    if (audioRoot.existsSync()) audioRoot.deleteSync(recursive: true);
  });

  Future<void> insert(String id) async {
    final dir = Directory('${audioRoot.path}/$id')..createSync(recursive: true);
    final file = File('${dir.path}/audio.m4a')..writeAsBytesSync(const [0]);
    await db.insertRecording(
      id: id,
      createdAt: DateTime(2026, 8, 29, 9, 15),
      durationMs: 207000,
      audioPath: file.path,
    );
    await db.setTranscript(id, 'Transkrypt nagrania $id', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
  }

  /// Patrz recording_detail_screen_test.dart: bez zaslepki konstruktor AudioPlayer wola
  /// kanaly platformowe, ktorych w tescie nie ma.
  void stubAudioPlayers(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final name in const ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    const events = EventChannel('xyz.luan/audioplayers.global/events');
    messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() => messenger.setMockStreamHandler(events, null));
  }

  Future<void> pumpLibrary(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    stubAudioPlayers(tester);

    routes = RouteCounter();
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        const LibraryScreen(),
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
        navigatorObservers: [routes],
      ),
    ));
    // Pierwsza klatka to jeszcze stan ladowania strumienia drift, druga niesie juz dane.
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  // UWAGA NA KOLEJNOSC: ten test musi zostac PIERWSZY w pliku i to nie jest kaprys.
  // audioplayers trzyma completer globalnej inicjalizacji w zmiennej na poziomie biblioteki
  // i tworzy go raz — w strefie fake-async tego testu, ktory pierwszy powola AudioPlayer.
  // Kazdy pozniejszy test dostaje future domkniety w strefie, ktorej nikt juz nie pompuje,
  // wiec `AudioPlayer.stop()` wisi tam w nieskonczonosc. Testy, ktore tylko RYSUJA panel,
  // niczego na odtwarzaczu nie awaituja i pulapki nie widza; ten jeden — widzi.
  testWidgets('kasowanie z panelu zostawia pusty panel i nie zdejmuje trasy',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, plL10n.detailDelete));
    // `testWidgets` biegnie w strefie fake-async, w ktorej prawdziwe I/O bazy nie dostaje
    // obrotu petli zdarzen — samo pompowanie klatek nigdy by sie tego nie doczekalo, choc
    // wyglada na to, ze powinno. Drift wykonuje operacje po kolei, a kasowanie weszlo do
    // kolejki przed tym odczytem: kiedy ten await wraca, usuniecie na pewno sie skonczylo.
    // Synchronizacja przez kolejnosc, nie przez odmierzanie czasu; petla, bo lancuch ma
    // kilka takich krokow, a limit jest twardy, zeby brak reakcji konczyl sie asercja
    // ponizej, a nie zawieszeniem testu.
    for (var i = 0; i < 20 && container.read(selectedRecordingProvider) != null; i++) {
      await db.getRecording('a');
      await tester.pump();
    }
    expect(container.read(selectedRecordingProvider), isNull,
        reason: 'po skasowaniu panel wraca do stanu pustego. Jesli to padlo zaraz po dodaniu '
            'nowego testu WYZEJ w tym pliku — patrz komentarz nad tym testem: kasowanie '
            'awaituje AudioPlayer.stop(), ktory dziala tylko w tescie powolujacym odtwarzacz '
            'jako pierwszy.');
    expect(find.byType(RecordingDetailView), findsNothing);
    expect(await db.getRecording('a'), isNull);
    // Lista zostaje na miejscu i pokazuje juz stan pusty biblioteki.
    expect(find.text(plL10n.libraryEmptyNoRecordings), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('szeroki ekran: stukniecie w karte wypelnia panel obok, bez nowej trasy',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));

    expect(find.byType(RecordingDetailView), findsNothing,
        reason: 'bez wyboru panel stoi pusty');

    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(routes.pushes, 0, reason: 'panel nie jest osobna trasa, wiec nie ma czego pushowac');
    expect(find.byType(RecordingDetailView), findsOneWidget);
    expect(container.read(selectedRecordingProvider), 'a');

    // Naglowek listy zostaje widoczny obok panelu — to jest sedno ukladu dwupanelowego.
    expect(find.text(plL10n.libraryTitle), findsOneWidget);
    expect(tester.getTopLeft(find.byType(RecordingDetailView)).dx, 400,
        reason: 'makieta daje liscie 400 px, panel zaczyna sie tuz za nia');

    await unmount(tester);
  });

  testWidgets('szeroki ekran: panel niesie naglowek z makiety, bez paska aplikacji',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppBar), findsNothing, reason: 'panel nie ma wlasnego paska aplikacji');
    expect(find.text('2026-08-29 09:15 · 3:27 · ${plL10n.statusDone}'), findsOneWidget,
        reason: 'makieta sklada date, dlugosc i status w jedna linie techniczna');
    // Data nie moze pojawic sie w panelu drugi raz, na karcie odtwarzacza. Na liscie obok
    // zostaje — tam jest jedynym opisem nagrania.
    expect(
      find.descendant(
        of: find.byType(RecordingDetailView),
        matching: find.text('2026-08-29 09:15'),
      ),
      findsNothing,
    );
    expect(find.byIcon(Symbols.delete_rounded), findsOneWidget);
    expect(find.text(plL10n.detailTranscriptLabel), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('szeroki ekran: wybor innego nagrania przestawia panel', (tester) async {
    await insert('a');
    await insert('b');
    await pumpLibrary(tester, size: const Size(1280, 800));

    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();
    expect(container.read(selectedRecordingProvider), 'a');

    await tester.tap(find.text('Transkrypt nagrania b'));
    await tester.pump();
    await tester.pump();

    expect(container.read(selectedRecordingProvider), 'b');
    expect(routes.pushes, 0);

    await unmount(tester);
  });

  testWidgets('waski ekran: stukniecie w karte otwiera osobna trase, jak dotad',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(412, 892));

    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pumpAndSettle();

    expect(routes.pushes, 1, reason: 'bez panelu szczegoly musza isc na pelny ekran');
    expect(find.byType(RecordingDetailScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget, reason: 'pelny ekran ma pasek z powrotem');
    expect(container.read(selectedRecordingProvider), isNull,
        reason: 'waski uklad nie tyka providera wyboru');

    await unmount(tester);
  });
}
