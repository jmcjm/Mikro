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
import 'package:mikro/features/library/recording_detail_screen.dart';

import '../../support/l10n_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
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

  Future<void> pumpDetail(WidgetTester tester, String id) async {
    stubAudioPlayers(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: localizedApp(
        RecordingDetailScreen(recordingId: id),
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
    expect(tester.getSize(bars().at(0)).height, 56, reason: 'pelna amplituda to caly pasek');
    expect(tester.getSize(bars().at(1)).height, 28);
    expect(tester.getSize(bars().at(2)).height, 14);
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
}
