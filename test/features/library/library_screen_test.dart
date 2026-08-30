import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/core/theme/app_theme.dart';
import 'package:mikro/features/library/library_screen.dart';

import '../../support/l10n_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(
    String id, {
    DateTime? createdAt,
    int durationMs = 1000,
  }) =>
      db.insertRecording(
        id: id,
        createdAt: createdAt ?? DateTime(2026, 8, 29, 9, 15),
        durationMs: durationMs,
        audioPath: '/tmp/$id.m4a',
      );

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: localizedApp(
        const LibraryScreen(),
        theme: buildTheme(palette: AppPalette.md3, brightness: Brightness.light),
      ),
    ));
    // Pierwsza klatka to jeszcze stan ladowania strumienia drift, druga niesie juz dane.
    await tester.pump();
    await tester.pump();
  }

  /// Odmontowanie ekranu przed koncem testu. Subskrypcja strumienia drift wypisuje sie przez
  /// zerowy Timer, ktory binding zglosilby jako "A Timer is still pending", gdyby powstal juz
  /// po zamknieciu testu — patrz ten sam zabieg w test/widget_test.dart.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('pusta biblioteka pokazuje stan pusty z makiety', (tester) async {
    await pumpLibrary(tester);

    expect(find.text(plL10n.libraryEmptyNoRecordings), findsOneWidget);
    expect(find.text(plL10n.libraryEmptyDescription), findsOneWidget);
    expect(find.byIcon(Symbols.library_music_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('karta gotowego nagrania: data, odznaka, transkrypt, czas i model',
      (tester) async {
    await insert('a', durationMs: 207000);
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-large-v3-turbo');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpLibrary(tester);

    expect(find.text('2026-08-29 09:15'), findsOneWidget);
    expect(find.text(plL10n.statusDone), findsOneWidget);
    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('3:27'), findsOneWidget);
    expect(find.text('whisper-large-v3-turbo'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('nagranie w przetwarzaniu ma odznake statusu i pasek postepu',
      (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.tagging);

    await pumpLibrary(tester);

    expect(find.text(plL10n.statusTagging), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('karta bledu pokazuje komunikat i przycisk ponowienia', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'Limit 25 MB');

    await pumpLibrary(tester);

    expect(find.text(plL10n.statusError), findsOneWidget);
    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.libraryRetry), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('pasek filtru zawiera tagi z calej biblioteki i zawezza liste',
      (tester) async {
    await insert('a', createdAt: DateTime(2026, 8, 29, 9, 15));
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.setTags('a', ['spotkanie']);
    await insert('b', createdAt: DateTime(2026, 8, 28, 9, 15));
    await db.setTranscript('b', 'Lista zakupow', 'whisper-1');
    await db.setTags('b', ['zakupy']);

    await pumpLibrary(tester);

    expect(find.text(plL10n.libraryFilterAll), findsOneWidget);
    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('Lista zakupow'), findsOneWidget);

    // Chip tagu wystepuje dwa razy: w pasku filtru i na karcie nagrania. Filtr jest pierwszy
    // w drzewie, bo pasek stoi nad lista.
    await tester.tap(find.text('spotkanie').first);
    await tester.pump();

    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('Lista zakupow'), findsNothing);

    await tester.tap(find.text(plL10n.libraryFilterAll));
    await tester.pump();

    expect(find.text('Lista zakupow'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('brak trafien wyszukiwania zachowuje komunikat z T12', (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpLibrary(tester);
    await tester.enterText(find.byType(TextField), 'zupelnie-czegos-innego');
    await tester.pump();

    expect(find.text(plL10n.libraryEmptyNoResults), findsOneWidget);
    expect(find.text(plL10n.libraryEmptyNoRecordings), findsNothing);

    await unmount(tester);
  });

  testWidgets('STRAZNIK: bogata lista miesci sie w oknie z makiety (412x892)',
      (tester) async {
    // Domyslne okno testu ma 800x600, wiec szerokie karty nigdy nie zdaza sie zlamac.
    // Makieta jest wezsza i wyzsza — a font testowy ma glify 1em, czyli teksty sa tu
    // szersze niz w Roboto. Jesli uklad przezyje te kombinacje, na urzadzeniu tez przezyje.
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await insert('a', createdAt: DateTime(2026, 8, 29, 9, 15), durationMs: 207000);
    await db.setTranscript(
        'a', 'Notatka ze standupu: przenosimy release na wtorek, bo migracja bazy nie '
        'jest gotowa i trzeba dorzucic testy.', 'whisper-large-v3-turbo');
    await db.updateStatus('a', RecordingStatus.done);
    await db.setTags('a', ['spotkanie', 'release', 'baza danych']);
    await insert('b', createdAt: DateTime(2026, 8, 28, 21, 3), durationMs: 2518000);
    await db.updateStatus('b', RecordingStatus.error,
        errorMessage: 'Nagranie przekracza limit 25 MB — za dlugie do transkrypcji.');

    await pumpLibrary(tester);

    // Brak wyjatku RenderFlex to sedno tego testu; asercje pilnuja, ze karty faktycznie
    // sie zbudowaly, a nie ze test przeszedl na pustym ekranie.
    expect(find.text(plL10n.statusDone), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.libraryRetry), findsOneWidget);

    await unmount(tester);
  });
}
