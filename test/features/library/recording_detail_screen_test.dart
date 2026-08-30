import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/core/audio/waveform.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/theme/app_theme.dart';
import 'package:mikro/features/library/library_styles.dart';
import 'package:mikro/features/library/recording_detail_screen.dart';
import 'package:mikro/l10n/app_localizations_en.dart';

import '../../support/l10n_harness.dart';

/// Globalna warstwa audioplayers bez kanalu platformowego. Liczy sie tu przede wszystkim to,
/// ze to INNA instancja niz poprzednio: `ensureInitialized` porownuje ja z zapamietana i po
/// zmianie przechodzi inicjacje jeszcze raz, w strefie biezacego testu. Przy okazji `init`
/// wraca od razu, bez rundy po kanale.
class _FakeGlobalPlatform extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}

/// Blad z przewidywalnym toString: banner sklada komunikat wprost z niego, wiec test moze
/// porownac cale zdanie zamiast szukac fragmentu.
class _FakeDbError {
  @override
  String toString() => 'baza padla';
}

void main() {
  late AppDatabase db;

  /// Dziennik wywolan kanalu odtwarzacza, w kolejnosci, w jakiej ekran je wyslal. Testy
  /// przewijania i predkosci patrza wlasnie tu: to jedyne miejsce, w ktorym widac, ILE RAZY
  /// karta naprawde ruszyla odtwarzacz.
  final playerCalls = <MethodCall>[];

  setUp(() {
    playerCalls.clear();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Globalna inicjacja audioplayers przebiega RAZ na proces, a Completer, na ktory czeka
    // kazdy rozkaz dla odtwarzacza, zostaje w strefie tego testu, ktory ja odpalil. W kazdym
    // nastepnym tescie ten future jest wprawdzie spelniony, ale jego kontynuacje ida do
    // kolejki martwej strefy — nikt ich nie przekreca, wiec seek czy setPlaybackRate nigdy
    // nie dochodzi do kanalu. Swiezy globalny interfejs platformy wymusza inicjacje od nowa,
    // juz w strefie biezacego testu. Bez tego kazdy test rozkazow dla odtwarzacza musialby
    // byc pierwszy w pliku.
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalPlatform();
  });
  tearDown(() => db.close());

  Future<void> insert(String id, {String? waveform}) => db.insertRecording(
        id: id,
        createdAt: DateTime(2026, 8, 29, 9, 15),
        durationMs: 207000,
        audioPath: '/tmp/$id.m4a',
        waveform: waveform,
      );

  /// audioplayers nie ma implementacji w srodowisku testowym: konstruktor AudioPlayer wola
  /// `init` na kanale globalnym i podpina sie pod jego strumien zdarzen. Bez zaslepki te
  /// wywolania wracaja jako MissingPluginException — czasem juz po zakonczeniu testu, co robi
  /// z tego migoczaca awarie zaleznie od obciazenia maszyny.
  ///
  /// Zaslepka zapisuje wywolania do [playerCalls] i UDAJE potwierdzenie przewijania. To drugie
  /// nie jest ozdobnikiem: `AudioPlayer.seek` czeka na zdarzenie `audio.onSeekComplete` z
  /// kanalu zdarzen odtwarzacza i bez niego wisi az do wlasnego limitu czasu, zostawiajac
  /// w tescie tykajacy timer. Kanal zdarzen ma w nazwie identyfikator odtwarzacza, wiec
  /// zaslepiamy go dopiero wtedy, gdy ten identyfikator przyjdzie w wywolaniu `create`.
  /// [confirmSeek] rozstrzyga, czy udawana warstwa natywna potwierdza przewijanie. Ustawione
  /// na `false` odwzorowuje platforme, ktora seek przyjmuje i milczy — jedyna sciezka, na
  /// ktorej wychodzi, czy karta nie zostawia fantomowej pozycji.
  void stubAudioPlayers(WidgetTester tester, {bool confirmSeek = true}) {
    final messenger = tester.binding.defaultBinaryMessenger;
    MockStreamHandlerEventSink? playerEvents;

    void stubPlayerEvents(String playerId) {
      final channel = EventChannel('xyz.luan/audioplayers/events/$playerId');
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(onListen: (_, sink) {
          // Cialo blokowe, a nie strzalka: `inline` koduje zwrocona wartosc jako odpowiedz
          // kanalu, a sink nie ma jak przez niego przejsc.
          playerEvents = sink;
        }),
      );
      addTearDown(() => messenger.setMockStreamHandler(channel, null));
    }

    for (final name in const ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async {
        playerCalls.add(call);
        final args = call.arguments as Map<Object?, Object?>?;
        switch (call.method) {
          case 'create':
            stubPlayerEvents(args!['playerId']! as String);
          case 'setSourceUrl':
            // Gotowosc zrodla melduje osobne zdarzenie; `setSource` czeka na nie i bez niego
            // wisi az do wlasnego limitu.
            playerEvents?.success(
                <String, dynamic>{'event': 'audio.onPrepared', 'value': true});
          case 'seek':
            if (confirmSeek) {
              playerEvents?.success(<String, dynamic>{'event': 'audio.onSeekComplete'});
            }
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    const events = EventChannel('xyz.luan/audioplayers.global/events');
    messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() => messenger.setMockStreamHandler(events, null));
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    String id, {
    Locale locale = const Locale('pl'),
    bool confirmSeek = true,
  }) async {
    stubAudioPlayers(tester, confirmSeek: confirmSeek);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: localizedApp(
        RecordingDetailScreen(recordingId: id),
        locale: locale,
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
      ),
    ));
    // Pierwsza klatka to jeszcze stan ladowania strumienia drift, druga niesie juz dane.
    await tester.pump();
    await tester.pump();
  }

  /// Patrz komentarz przy tej samej pomocniczej w library_screen_test.dart — odmontowanie
  /// pozwala driftowi odpalic timer wypisania sie ze strumienia, zanim test sie zamknie.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('gotowe nagranie: naglowek, karta transkrypcji i podpis modelu',
      (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-large-v3-turbo');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.detailTitle), findsOneWidget);
    expect(find.text('2026-08-29 09:15'), findsOneWidget);
    expect(find.text(plL10n.statusDone), findsOneWidget);
    expect(find.text(plL10n.detailTranscriptLabel), findsOneWidget);
    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('model: whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('3:27'), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('naglowek pelnego ekranu niesie tytul nagrania', (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.setTitle('a', 'Standup i przesuniecie release');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.text('Standup i przesuniecie release'), findsOneWidget);
    expect(find.text(plL10n.detailTitle), findsNothing,
        reason: 'nazwa rodzajowa ustepuje tytulowi, gdy nagranie go ma');

    await unmount(tester);
  });

  testWidgets('naglowek bez tytulu zostaje przy nazwie rodzajowej', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.detailTitle), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('bez transkryptu ekran pokazuje postep i etykiete statusu', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.transcribing);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.statusTranscribing), findsNWidgets(2)); // odznaka i podpis pod spinnerem
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Bez transkryptu nie ma czego udostepniac ani kopiowac.
    expect(find.byIcon(Symbols.share_rounded), findsNothing);
    expect(find.byIcon(Symbols.content_copy_rounded), findsNothing);

    await unmount(tester);
  });

  testWidgets('blad przetwarzania: komunikat i ponowienie', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'Limit 25 MB');

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.statusError), findsOneWidget);
    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.detailRetryProcessing), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('usuniete nagranie znika z ekranu z komunikatem', (tester) async {
    await pumpDetail(tester, 'nie-ma-takiego');

    expect(find.text(plL10n.detailRecordingDeleted), findsOneWidget);

    await unmount(tester);
  });

  /// Podmienia caly strumien nagran, zeby dalo sie postawic ekran w stanie, ktorego drift
  /// w tescie nie wyprodukuje: awaria bazy albo strumien, ktory jeszcze nic nie oddal.
  Future<void> pumpWithStream(
      WidgetTester tester, Stream<List<RecordingWithTags>> stream) async {
    stubAudioPlayers(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        recordingsStreamProvider.overrideWith((ref) => stream),
      ],
      child: localizedApp(
        const RecordingDetailScreen(recordingId: 'a'),
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('awaria bazy melduje sie bledem, a nie komunikatem o skasowaniu',
      (tester) async {
    await pumpWithStream(
        tester, Stream<List<RecordingWithTags>>.error(_FakeDbError()));

    expect(find.text(plL10n.libraryDatabaseError('baza padla')), findsOneWidget);
    expect(find.text(plL10n.detailRecordingDeleted), findsNothing,
        reason: 'padnieta baza to nie to samo, co nagranie usuniete przez uzytkownika — '
            'komunikat o skasowaniu kazalby szukac wpisu, ktory wciaz tam jest');

    await unmount(tester);
  });

  testWidgets('strumien bez pierwszej wartosci pokazuje postep, nie komunikat o skasowaniu',
      (tester) async {
    // Strumien, ktory nigdy nic nie oddaje: ekran zostaje w stanie ladowania.
    final pending = StreamController<List<RecordingWithTags>>();
    addTearDown(pending.close);

    await pumpWithStream(tester, pending.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(plL10n.detailRecordingDeleted), findsNothing,
        reason: 'zanim strumien cokolwiek odda, o istnieniu nagrania nic nie wiadomo');

    await unmount(tester);
  });

  testWidgets('STRAZNIK: bez natywnego arkusza udostepnianie kopiuje do schowka',
      (tester) async {
    // Testy chodza na Linuksie, gdzie share_plus skladalby `mailto:` i oddawal go
    // url_launcherowi. Ekran musi wtedy wejsc w zamiennik: schowek plus snackbar.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');
    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['Notatka ze standupu']);
    expect(find.text(plL10n.detailCopiedTranscript), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('kopiowanie z karty transkrypcji zachowuje komunikat z T12', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');
    await tester.tap(find.byIcon(Symbols.content_copy_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['Notatka ze standupu']);
    expect(find.text(plL10n.detailCopied), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('STRAZNIK: szczegoly z tagami i dlugim transkryptem w oknie makiety',
      (tester) async {
    // Patrz blizniaczy test w library_screen_test.dart — okno 412x892 zamiast domyslnego
    // 800x600 lamie uklad tak, jak zrobi to telefon.
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await insert('a');
    await db.setTranscript(
        'a',
        'Notatka ze standupu: przenosimy release na wtorek, bo migracja bazy nie jest '
        'gotowa. Kuba bierze migracje i do poniedzialku dorzuca testy. Do sprawdzenia '
        'jeszcze limit uploadu w pipeline.',
        'whisper-large-v3-turbo');
    await db.updateStatus('a', RecordingStatus.done);
    await db.setTags('a', ['spotkanie', 'release', 'baza danych']);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.detailTranscriptLabel), findsOneWidget);
    expect(find.text('model: whisper-large-v3-turbo'), findsOneWidget);

    await unmount(tester);
  });


  // --- reczna edycja tagow: kafelek "+ tag" i kasowanie chipa ---

  /// Nagranie gotowe do ogladania. Transkrypt jest tu istotny: bez niego karta transkrypcji
  /// krecilaby spinner bez konca, a wtedy zadne `pumpAndSettle` juz nie wroci.
  Future<void> insertReady(String id, {List<String> tags = const []}) async {
    await insert(id);
    await db.setTranscript(id, 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
    if (tags.isNotEmpty) await db.setTags(id, tags);
  }

  /// Otwiera okno dodawania tagu. Pompujemy jawnie zamiast `pumpAndSettle`, zeby test nie
  /// zalezal od tego, czy w drzewie akurat nie ma jakiegos zywego tickera.
  Future<void> openAddTagDialog(WidgetTester tester) async {
    await tester.tap(find.byType(AddTagChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Zapis tagu idzie prawdziwym I/O bazy, ktore w strefie fake-async testu nie dostaje
  /// obrotu petli zdarzen samo z siebie. Drift wykonuje operacje po kolei, wiec odczyt
  /// wpuszczony do tej samej kolejki wraca dopiero PO zapisie — synchronizacja przez
  /// kolejnosc, nie przez odmierzanie czasu. Patrz ten sam zabieg w library_two_pane_test.
  Future<void> settleDb(WidgetTester tester, {required bool Function() until}) async {
    for (var i = 0; i < 20 && !until(); i++) {
      await db.getRecording('a');
      await tester.pump();
    }
  }

  /// Tagi nagrania odczytane zapytaniem JEDNORAZOWYM. `watchAllWithTags().first` w tescie
  /// widgetowym wiesza sie na amen: emisja strumienia drifta potrzebuje obrotu petli zdarzen,
  /// ktorego czekanie na `first` nigdy nie odda, bo w strefie fake-async czas plynie tylko
  /// przy pompowaniu klatek.
  Future<List<String>> tagsOf(String id) async {
    final rows = await db.customSelect(
      'SELECT t.name AS name FROM tags t JOIN recording_tags rt ON rt.tag_id = t.id '
      'WHERE rt.recording_id = ? ORDER BY t.name',
      variables: [Variable.withString(id)],
    ).get();
    return [for (final row in rows) row.data['name'] as String];
  }

  testWidgets('rzad tagow ma kafelek "+ tag", ktory dopisuje tag do nagrania',
      (tester) async {
    await insertReady('a', tags: ['spotkanie']);

    await pumpDetail(tester, 'a');

    expect(find.byType(AddTagChip), findsOneWidget);
    await openAddTagDialog(tester);

    expect(find.text(plL10n.detailAddTagTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Release  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, plL10n.detailAddTagConfirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settleDb(tester, until: () => find.text('release').evaluate().isNotEmpty);

    expect(await tagsOf('a'), ['release', 'spotkanie'],
        reason: 'nazwa idzie do bazy przycieta i mala litera, jak tagi z modelu');
    expect(find.text('release'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('kafelek "+ tag" jest dostepny takze przy nagraniu bez tagow', (tester) async {
    // Bez tego pierwszego tagu recznie nie da sie dodac w ogole.
    await insertReady('a');

    await pumpDetail(tester, 'a');

    expect(find.byType(AddTagChip), findsOneWidget);
    expect(tester.getSize(find.byType(AddTagChip)).height, 32,
        reason: 'makieta daje kafelkowi te sama wysokosc, co chipowi tagu');
    expect(
      find.descendant(of: find.byType(AddTagChip), matching: find.byIcon(Symbols.add_rounded)),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('okno dodawania: pusty wpis nie pozwala zatwierdzic', (tester) async {
    await insertReady('a');

    await pumpDetail(tester, 'a');
    await openAddTagDialog(tester);

    FilledButton confirm() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, plL10n.detailAddTagConfirm));

    expect(confirm().onPressed, isNull, reason: 'puste pole nie ma czego zapisac');

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(confirm().onPressed, isNull, reason: 'same biale znaki to dalej pusty tag');

    await tester.enterText(find.byType(TextField), 'release');
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await unmount(tester);
  });

  testWidgets('okno dodawania: duplikat w ramach nagrania jest blokowany bez wzgledu na wielkosc liter',
      (tester) async {
    await insertReady('a', tags: ['spotkanie']);

    await pumpDetail(tester, 'a');
    await openAddTagDialog(tester);

    await tester.enterText(find.byType(TextField), 'SPOTKANIE');
    await tester.pump();

    expect(find.text(plL10n.detailAddTagDuplicate), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, plL10n.detailAddTagConfirm))
          .onPressed,
      isNull,
    );

    await unmount(tester);
  });

  testWidgets('chip tagu w szczegolach kasuje tag od razu, bez okna potwierdzenia',
      (tester) async {
    await insertReady('a', tags: ['spotkanie', 'release']);

    await pumpDetail(tester, 'a');

    expect(find.byIcon(Symbols.close_rounded), findsNWidgets(2),
        reason: 'kazdy chip w szczegolach ma wlasny krzyzyk');

    await tester.tap(find.descendant(
      of: find.widgetWithText(TagChip, 'spotkanie'),
      matching: find.byIcon(Symbols.close_rounded),
    ));
    await tester.pump();
    await settleDb(tester, until: () => find.text('spotkanie').evaluate().isEmpty);

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'niska stawka, odwracalne przez "+ tag"');
    expect(await tagsOf('a'), ['release']);
    expect(find.text('spotkanie'), findsNothing);

    await unmount(tester);
  });

  // --- przebieg na karcie odtwarzacza (D2f) ---

  /// Slupek to jedyny DecoratedBox wewnatrz [WaveformBars], wiec liczy sie i mierzy
  /// bezposrednio po nim.
  Finder bars() => find.descendant(
        of: find.byType(WaveformBars),
        matching: find.byType(DecoratedBox),
      );

  testWidgets('karta odtwarzacza rysuje slupki zapisanego przebiegu', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Pierwsze trzy slupki maja znane wysokosci, reszta wypelnia pasek do liczby z makiety.
    final levels = <double>[1.0, 0.5, 0.25, ...List.filled(kWaveformBuckets - 4, 0.4), 0.0];
    await insert('a', waveform: encodeWaveform(levels));
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(bars(), findsNWidgets(kWaveformBuckets),
        reason: 'makieta ma $kWaveformBuckets slupkow');
    expect(tester.getSize(bars().at(0)).height, 64,
        reason: 'pelna amplituda to caly pasek, a ten ma w karcie telefonu 64 px');
    expect(tester.getSize(bars().at(1)).height, 32);
    expect(tester.getSize(bars().at(2)).height, 16);
    expect(tester.getSize(bars().at(kWaveformBuckets - 1)).height, 2,
        reason: 'cisza zostaje widoczna jako kreska, inaczej w pasku byla by dziura');

    // Slupki dziela szerokosc po rowno i sa oddzielone odstepem z makiety (3 px).
    final first = tester.getRect(bars().at(0));
    final second = tester.getRect(bars().at(1));
    expect(second.width, moreOrLessEquals(first.width, epsilon: 0.5));
    expect(second.left - first.right, moreOrLessEquals(3, epsilon: 0.5));

    // Slupki sa wysrodkowane w pionie, tak jak w makiecie (align-items:center).
    expect(first.center.dy, moreOrLessEquals(second.center.dy, epsilon: 0.5));

    await unmount(tester);
  });

  testWidgets('nagranie bez zapisanego przebiegu nie dostaje wymyslonych slupkow',
      (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformBars), findsNothing,
        reason: 'nagrania sprzed migracji nie maja obwiedni i nie wolno jej zmyslac');
    // Karta ma dzialac dalej: transport i czasy zostaja na miejscu.
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
    expect(find.text('3:27'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('uszkodzony zapis przebiegu nie wywraca ekranu', (tester) async {
    await insert('a', waveform: 'to-nie-jest-json');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformBars), findsNothing);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('naglowek ma wysokosc z makiety', (tester) async {
    await insert('a');

    await pumpDetail(tester, 'a');

    expect(tester.getSize(find.byType(AppBar)).height, 64);

    await unmount(tester);
  });

  // --- przebieg jako powierzchnia przewijania, skoki o 10 s i predkosc (D2g) ---

  /// Pozycje przewiniec w kolejnosci, w jakiej ekran wyslal je do odtwarzacza. Zaslepka kanalu
  /// to jedyne miejsce, w ktorym widac, ILE RAZY karta go ruszyla — a o to chodzi w calej
  /// dyscyplinie jednego seeku na gest.
  List<int> seeks() => [
        for (final call in playerCalls)
          if (call.method == 'seek') (call.arguments as Map)['position'] as int,
      ];

  List<double> rates() => [
        for (final call in playerCalls)
          if (call.method == 'setPlaybackRate')
            (call.arguments as Map)['playbackRate'] as double,
      ];

  /// Rozkaz dla odtwarzacza idzie kanalem platformowym tam i z powrotem, a przewijanie przed
  /// pierwszym odtworzeniem to dwie takie rundy plus zdarzenie gotowosci zrodla. Kilka klatek
  /// daje im wszystkim dojsc; `pumpAndSettle` odpada, bo w drzewie moze stac zywy ticker.
  Future<void> settlePlayer(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Nazwy wywolan kanalu w kolejnosci, w jakiej ekran je wyslal.
  List<String> methods() => [for (final call in playerCalls) call.method];

  /// Nagranie z pelnym przebiegiem. Wszystkie slupki tej samej wysokosci, bo te testy patrza
  /// na podzial zagrane/niezagrane i na gesty, a nie na ksztalt obwiedni.
  Future<void> insertWithWave(String id) async {
    await insert(id, waveform: encodeWaveform(List.filled(kWaveformBuckets, 0.5)));
    await db.setTranscript(id, 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
  }

  testWidgets('stukniecie w przebieg przewija dokladnie raz', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'stukniecie to jeden seek, nie seria');
    expect(seeks().single, closeTo(207000 / 2, 300),
        reason: 'srodek paska to polowa nagrania');

    await unmount(tester);
  });

  testWidgets('przeciaganie po przebiegu przewija raz, na koncu gestu', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    final bar = tester.getRect(find.byType(WaveformBars));
    await tester.drag(find.byType(WaveformSeekBar), const Offset(60, 0));
    await settlePlayer(tester);

    expect(seeks().length, 1,
        reason: 'przeciaganie prowadzi sam kursor; odtwarzacz rusza sie raz, na koncu gestu');
    expect(seeks().single, closeTo((bar.width / 2 + 60) / bar.width * 207000, 300),
        reason: 'seek idzie tam, gdzie palec skonczyl, a nie tam, gdzie zaczal');

    await unmount(tester);
  });

  testWidgets('przebieg zastepuje suwak pozycji', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformSeekBar), findsOneWidget);
    expect(find.byType(Slider), findsNothing,
        reason: 'po redesignie przewija sie po slupkach, osobnego toru z uchwytem juz nie ma');

    await unmount(tester);
  });

  testWidgets('nagranie bez przebiegu zostaje przy dotychczasowym suwaku', (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformSeekBar), findsNothing);
    expect(find.byType(Slider), findsOneWidget,
        reason: 'obwiedni nie wolno zmyslac, a przewijac trzeba dac sie tak samo');

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'suwak tez przewija raz, na koncu gestu');

    await unmount(tester);
  });

  testWidgets('slupki dziela sie na zagrane i niezagrane wedlug pozycji', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    final scheme = Theme.of(tester.element(find.byType(WaveformBars))).colorScheme;
    final rest = scheme.outlineVariant.withValues(alpha: 0.75);
    Color colorOf(int i) =>
        (tester.widget<DecoratedBox>(bars().at(i)).decoration as BoxDecoration).color!;

    expect(colorOf(0), rest, reason: 'przed przewinieciem zaden slupek nie jest zagrany');

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(colorOf(0), scheme.primary);
    expect(colorOf(kWaveformBuckets ~/ 2 - 1), scheme.primary);
    expect(colorOf(kWaveformBuckets - 1), rest,
        reason: 'polowa nagrania zostawia druga polowe slupkow przygaszona');

    await unmount(tester);
  });

  testWidgets('kursor stoi na pozycji i wystaje poza pas slupkow', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    // Kursor to jedyny DecoratedBox powierzchni przewijania spoza paska slupkow. W Stacku
    // stoi PO nich, wiec w kolejnosci drzewa jest ostatni.
    Finder cursor() => find
        .descendant(of: find.byType(WaveformSeekBar), matching: find.byType(DecoratedBox))
        .last;

    final bar = tester.getRect(find.byType(WaveformBars));
    expect(tester.getSize(cursor()).width, 4);
    expect(tester.getSize(cursor()).height, bar.height + 8,
        reason: 'makieta: top:-4 i bottom:-4 wzgledem pasa slupkow');
    expect(tester.getRect(cursor()).left, bar.left,
        reason: 'na poczatku nagrania kursor jest wciagniety w pas, nie wisi polowa obok');

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(tester.getRect(cursor()).center.dx, closeTo(bar.center.dx, 1),
        reason: 'po stuknieciu w srodek kursor staje w srodku');

    await unmount(tester);
  });

  testWidgets('czasy ida za przewinieciem', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    expect(find.text('0:00'), findsOneWidget);

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(find.text('1:43'), findsOneWidget, reason: 'polowa z 3:27');
    expect(find.text('3:27'), findsOneWidget, reason: 'dlugosc nagrania sie nie rusza');

    await unmount(tester);
  });

  testWidgets('skoki o 10 s trzymaja sie granic nagrania i dzialaja bez odtwarzania',
      (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    Future<void> tapAction(String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      await tester.pump();
    }

    await tapAction(plL10n.detailForwardTooltip);
    expect(seeks(), [10000],
        reason: 'nic nie gra, a skok i tak przestawia miejsce startu');

    await tapAction(plL10n.detailRewindTooltip);
    expect(seeks(), [10000, 0]);

    await tapAction(plL10n.detailRewindTooltip);
    expect(seeks(), [10000, 0, 0], reason: 'przed zerem nie ma dokad cofac');

    await unmount(tester);
  });

  testWidgets('pigulka predkosci cykluje etykiete i melduje sie odtwarzaczowi', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    Future<void> tapPill() async {
      await tester.tap(find.byTooltip(plL10n.detailSpeedTooltip));
      await tester.pump();
      await tester.pump();
    }

    expect(find.text(plL10n.detailSpeedLabel('1,0')), findsOneWidget);
    await tapPill();
    expect(find.text(plL10n.detailSpeedLabel('1,25')), findsOneWidget);
    await tapPill();
    expect(find.text(plL10n.detailSpeedLabel('1,5')), findsOneWidget);
    await tapPill();
    expect(find.text(plL10n.detailSpeedLabel('2,0')), findsOneWidget);
    await tapPill();
    expect(find.text(plL10n.detailSpeedLabel('1,0')), findsOneWidget,
        reason: 'po ostatnim kroku cykl wraca na poczatek');

    expect(rates(), [1.25, 1.5, 2.0, 1.0],
        reason: 'kazde stukniecie melduje predkosc odtwarzaczowi, bez pomijania krokow');

    await unmount(tester);
  });

  testWidgets('etykieta predkosci idzie za jezykiem interfejsu', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a', locale: const Locale('en'));

    expect(find.text(AppLocalizationsEn().detailSpeedLabel('1.0')), findsOneWidget,
        reason: 'po angielsku separatorem dziesietnym jest kropka, nie przecinek');

    await unmount(tester);
  });

  // --- panel szerokiego ukladu ---

  /// Panel w szerokosci, jaka dostaje przy samym progu ukladu szerokiego: okno 840 px minus
  /// 80 px railu i 400 px listy zostawia mu 360 px. Wiersz transportu ma sie w tym zmiescic —
  /// przepelniony Row melduje blad i test pada.
  Future<void> pumpPanel(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    stubAudioPlayers(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: localizedApp(
        Scaffold(
          body: RecordingDetailView(recordingId: id, chrome: DetailChrome.panel),
        ),
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
      ),
    ));
    await settlePlayer(tester);
  }

  testWidgets('panel: nizszy pas, wiersz transportu i pigulka mieszcza sie przy progu',
      (tester) async {
    await insertWithWave('a');

    await pumpPanel(tester, 'a');

    expect(tester.getSize(find.byType(WaveformBars)).height, 52,
        reason: 'makieta desktopowa ma pas 52 px, nizszy niz 64 px karty telefonu');
    expect(find.byTooltip(plL10n.detailRewindTooltip), findsOneWidget);
    expect(find.byTooltip(plL10n.detailForwardTooltip), findsOneWidget);
    expect(find.text(plL10n.detailSpeedLabel('1,0')), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('panel: przewijanie, skoki i predkosc dzialaja jak na telefonie', (tester) async {
    await insertWithWave('a');

    await pumpPanel(tester, 'a');

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);
    expect(seeks().length, 1);
    expect(seeks().single, closeTo(207000 / 2, 300));

    await tester.tap(find.byTooltip(plL10n.detailForwardTooltip));
    await settlePlayer(tester);
    expect(seeks().last, closeTo(207000 / 2 + 10000, 300),
        reason: 'skok liczy sie od pozycji, na ktorej stoi kursor');

    await tester.tap(find.byTooltip(plL10n.detailSpeedTooltip));
    await settlePlayer(tester);
    expect(rates(), [1.25]);
    expect(find.text(plL10n.detailSpeedLabel('1,25')), findsOneWidget,
        reason: 'jedna predkosc na ekran, ta sama pigulka co na telefonie');

    await unmount(tester);
  });

  // --- leniwe wczytanie zrodla przy przewijaniu (runda fix 1) ---

  testWidgets('przewijanie przed odtwarzaniem wczytuje zrodlo i nie wlacza odtwarzania',
      (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(methods(), contains('setSourceUrl'),
        reason: 'bez wczytanego zrodla natywna warstwa nie ma czego przewijac — seek '
            'przechodzi bez skutku i bez potwierdzenia');
    expect(methods().indexOf('setSourceUrl'), lessThan(methods().indexOf('seek')),
        reason: 'najpierw zrodlo, potem przewiniecie');
    expect(methods(), isNot(contains('resume')),
        reason: 'gest przewijania nie wlacza odtwarzania — pauza zostaje pauza');
    expect(seeks().length, 1);
    expect(find.text('1:43'), findsOneWidget, reason: 'pozycja jest prawdziwa, nie fantomowa');
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget,
        reason: 'przycisk nadal zaprasza do odtwarzania');

    await unmount(tester);
  });

  testWidgets('skok o 10 s przed odtwarzaniem tez wczytuje zrodlo', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byTooltip(plL10n.detailForwardTooltip));
    await settlePlayer(tester);

    expect(methods(), contains('setSourceUrl'));
    expect(seeks(), [10000]);
    expect(find.text('0:10'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('odtwarzanie po przewinieciu wznawia, zamiast wczytywac zrodlo od nowa',
      (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);
    await tester.tap(find.byIcon(Symbols.play_arrow_rounded));
    await settlePlayer(tester);

    expect(methods().where((m) => m == 'setSourceUrl').length, 1,
        reason: 'drugie wczytanie zrodla skasowaloby wlasnie wybrana pozycje');
    expect(methods(), contains('resume'));
    expect(methods().lastIndexOf('resume'), greaterThan(methods().indexOf('seek')),
        reason: 'najpierw uzytkownik wybral miejsce, potem wcisnal play');

    await unmount(tester);
  });

  testWidgets('brak potwierdzenia przewijania nie zostawia fantomowej pozycji',
      (tester) async {
    // Limit audioplayers ustawiony DLUZEJ niz limit karty i tak, zeby nie zostawil po tescie
    // tykajacego timera. Chodzi o to, ktory z nich zdejmuje fantom: ma to zrobic karta,
    // a nie wtyczka po swoich 30 sekundach.
    final plugin = AudioPlayer.seekingTimeout;
    AudioPlayer.seekingTimeout = const Duration(seconds: 5);
    addTearDown(() => AudioPlayer.seekingTimeout = plugin);

    await insertWithWave('a');

    await pumpDetail(tester, 'a', confirmSeek: false);
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'przewiniecie zostalo wyslane');
    expect(find.text('1:43'), findsOneWidget,
        reason: 'poki proba trwa, kursor stoi tam, gdzie uzytkownik go postawil');

    await tester.pump(const Duration(seconds: 3)); // ponad limit karty, ponizej limitu wtyczki

    expect(find.text('0:00'), findsOneWidget,
        reason: 'niepotwierdzone przewijanie wraca do prawdziwej pozycji, i to od razu — '
            'a nie po pol minuty czekania wtyczki');
    expect(find.text('1:43'), findsNothing);

    // Domkniecie limitu wtyczki, zeby nie zostal na koniec testu jako tykajacy timer.
    await tester.pump(const Duration(seconds: 3));

    await unmount(tester);
  });
}
