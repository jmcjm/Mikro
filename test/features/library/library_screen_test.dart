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
import 'package:mikro/features/library/library_styles.dart';

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
    // First frame is still drift stream loading state, second frame carries data.
    await tester.pump();
    await tester.pump();
  }

  /// Unmount the screen before test ends. The drift stream subscription unregisters via
  /// a zero-duration Timer, which the binding would report as "A Timer is still pending" if created
  /// after test teardown — see identical approach in test/widget_test.dart.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty library shows empty state from mockup', (tester) async {
    await pumpLibrary(tester);

    expect(find.text(plL10n.libraryEmptyNoRecordings), findsOneWidget);
    expect(find.text(plL10n.libraryEmptyDescription), findsOneWidget);
    expect(find.byIcon(Symbols.library_music_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('done recording card: date, badge, transcript, duration and model',
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

  testWidgets('card with title shows title instead of first line of transcript',
      (tester) async {
    await insert('a', durationMs: 207000);
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-large-v3-turbo');
    await db.setTitle('a', 'Standup i przesuniecie release');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpLibrary(tester);

    expect(find.text('Standup i przesuniecie release'), findsOneWidget);
    expect(find.text('Notatka ze standupu'), findsNothing,
        reason: 'title replaces transcript in card body rather than appending to it');

    await unmount(tester);
  });

  testWidgets('card without title falls back to transcript', (tester) async {
    // Pre-v4 schema recordings have NULL title and must render exactly as before.
    await insert('a', durationMs: 207000);
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpLibrary(tester);

    expect(find.text('Notatka ze standupu'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('error card shows message even when recording already has a title',
      (tester) async {
    // Red background carries information that title must not obscure.
    await insert('a');
    await db.setTitle('a', 'Standup i przesuniecie release');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'Limit 25 MB');

    await pumpLibrary(tester);

    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.text('Standup i przesuniecie release'), findsNothing);

    await unmount(tester);
  });

  testWidgets('in-flight recording has status badge and progress bar',
      (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.tagging);

    await pumpLibrary(tester);

    expect(find.text(plL10n.statusTagging), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('error card shows message and retry button', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'Limit 25 MB');

    await pumpLibrary(tester);

    expect(find.text(plL10n.statusError), findsOneWidget);
    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.libraryRetry), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('filter bar contains tags from entire library and narrows list',
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

    // Tag chip appears twice: in filter bar and on recording card. Filter is first
    // in tree because the bar sits above the list.
    await tester.tap(find.text('spotkanie').first);
    await tester.pump();

    expect(find.text('Notatka ze standupu'), findsOneWidget);
    expect(find.text('Lista zakupow'), findsNothing);

    await tester.tap(find.text(plL10n.libraryFilterAll));
    await tester.pump();

    expect(find.text('Lista zakupow'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('tags on card and in filter remain navigation: no delete button and no "+ tag"',
      (tester) async {
    // Deleting and adding tags lives exclusively in detail screen. On the list a tag is a
    // filter button, so a close icon on the chip could easily be confused with clearing the filter.
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.setTags('a', ['spotkanie']);
    await db.updateStatus('a', RecordingStatus.done);

    await pumpLibrary(tester);

    expect(find.text('spotkanie'), findsNWidgets(2), reason: 'filter chip and card chip');
    expect(find.byIcon(Symbols.close_rounded), findsNothing);
    expect(find.byType(AddTagChip), findsNothing);

    await unmount(tester);
  });

  testWidgets('no search matches preserves message from T12', (tester) async {
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

  testWidgets('GUARD: rich list fits in mockup window (412x892)',
      (tester) async {
    // Default test window is 800x600, so wide cards would never wrap.
    // Mockup is narrower and taller — and test font has 1em glyphs, making text
    // wider than in Roboto. If layout survives this combination, it will survive on device as well.
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

    // Absence of RenderFlex overflow exception is the core of this test; assertions verify
    // that cards were actually built rather than test passing on an empty screen.
    expect(find.text(plL10n.statusDone), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.libraryRetry), findsOneWidget);

    await unmount(tester);
  });
}
