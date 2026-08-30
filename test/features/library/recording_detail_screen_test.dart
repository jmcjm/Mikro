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
import 'package:mikro/features/library/recording_detail_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(String id) => db.insertRecording(
        id: id,
        createdAt: DateTime(2026, 8, 29, 9, 15),
        durationMs: 207000,
        audioPath: '/tmp/$id.m4a',
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
      child: MaterialApp(
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
        home: RecordingDetailScreen(recordingId: id),
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

    expect(find.text('Nagranie'), findsOneWidget);
    expect(find.text('2026-08-29 09:15'), findsOneWidget);
    expect(find.text('Gotowe'), findsOneWidget);
    expect(find.text('TRANSKRYPCJA'), findsOneWidget);
    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('model: whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('3:27'), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('bez transkryptu ekran pokazuje postep i etykiete statusu', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.transcribing);

    await pumpDetail(tester, 'a');

    expect(find.text('Transkrypcja…'), findsNWidgets(2)); // odznaka i podpis pod spinnerem
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

    expect(find.text('Błąd'), findsOneWidget);
    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ponów przetwarzanie'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('usuniete nagranie znika z ekranu z komunikatem', (tester) async {
    await pumpDetail(tester, 'nie-ma-takiego');

    expect(find.text('Nagranie usunięte.'), findsOneWidget);

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
    expect(find.text('Skopiowano transkrypt do schowka.'), findsOneWidget);

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
    expect(find.text('Skopiowano.'), findsOneWidget);

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

    expect(find.text('TRANSKRYPCJA'), findsOneWidget);
    expect(find.text('model: whisper-large-v3-turbo'), findsOneWidget);

    await unmount(tester);
  });
}
