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
import 'package:mikro/features/library/library_styles.dart';
import 'package:mikro/features/library/recording_detail_screen.dart';
import 'package:mikro/features/library/selected_recording.dart';

import '../../support/l10n_harness.dart';

/// Counts routes pushed AFTER app launch. Initial route comes with `previousRoute` equal
/// to null and is not a detail screen opening.
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
    // Deleting a recording deletes the PARENT DIRECTORY of the audio file. With a path like
    // /tmp/a.m4a this would delete all of /tmp, so each recording gets its own directory
    // in a fresh temporary root.
    audioRoot = Directory.systemTemp.createTempSync('mikro-two-pane');
  });
  tearDown(() {
    db.close();
    if (audioRoot.existsSync()) audioRoot.deleteSync(recursive: true);
  });

  Future<void> insert(String id, {String? title}) async {
    final dir = Directory('${audioRoot.path}/$id')..createSync(recursive: true);
    final file = File('${dir.path}/audio.m4a')..writeAsBytesSync(const [0]);
    await db.insertRecording(
      id: id,
      createdAt: DateTime(2026, 8, 29, 9, 15),
      durationMs: 207000,
      audioPath: file.path,
    );
    await db.setTranscript(id, 'Transkrypt nagrania $id', 'whisper-1');
    if (title != null) await db.setTitle(id, title);
    await db.updateStatus(id, RecordingStatus.done);
  }

  /// See recording_detail_screen_test.dart: without stubbing, the AudioPlayer constructor calls
  /// platform channels that do not exist in test.
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
    // First frame is still drift stream loading state, second frame carries data.
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  // ORDER MATTERS: this test MUST remain FIRST in the file and this is not arbitrary.
  // audioplayers stores the global initialization completer in a library-level variable
  // and creates it once — in the fake-async zone of whichever test creates AudioPlayer first.
  // Every subsequent test receives a future completed in a zone that is no longer pumped,
  // so `AudioPlayer.stop()` hangs there indefinitely. Tests that only RENDER the panel
  // do not await anything on the player and do not hit this trap; this single test does.
  testWidgets('deleting from panel leaves empty panel and does not pop route',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, plL10n.detailDelete));
    // `testWidgets` runs in a fake-async zone where real database I/O does not receive
    // an event loop turn — frame pumping alone would never complete it, although
    // it looks like it should. Drift executes operations sequentially, and delete was queued
    // before this read: when this await returns, deletion is guaranteed to have finished.
    // Synchronization via ordering, not timeouts; loop because the chain has
    // several such steps, with a hard limit so lack of reaction triggers the assertion
    // below rather than hanging the test.
    for (var i = 0; i < 20 && container.read(selectedRecordingProvider) != null; i++) {
      await db.getRecording('a');
      await tester.pump();
    }
    expect(container.read(selectedRecordingProvider), isNull,
        reason: 'after deletion panel returns to empty state. If this failed right after adding '
            'a new test HIGHER in this file — see comment above this test: deletion '
            'awaits AudioPlayer.stop(), which only works in the test instantiating the player first.');
    expect(find.byType(RecordingDetailView), findsNothing);
    expect(await db.getRecording('a'), isNull);
    expect(Directory('${audioRoot.path}/a').existsSync(), isFalse,
        reason: 'recording directory follows database entry; guard against recursive deletion '
            'must filter foreign paths, not block the intended one');
    // List remains in place and now shows the empty library state.
    expect(find.text(plL10n.libraryEmptyNoRecordings), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('wide screen: tapping card fills side panel without new route',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));

    expect(find.byType(RecordingDetailView), findsNothing,
        reason: 'without selection panel remains empty');

    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(routes.pushes, 0, reason: 'panel is not a separate route, so nothing to push');
    expect(find.byType(RecordingDetailView), findsOneWidget);
    expect(container.read(selectedRecordingProvider), 'a');

    // List header remains visible next to panel — that is the essence of two-pane layout.
    expect(find.text(plL10n.libraryTitle), findsOneWidget);
    expect(tester.getTopLeft(find.byType(RecordingDetailView)).dx, 400,
        reason: 'mockup gives list 400 px, panel starts right after it');

    await unmount(tester);
  });

  testWidgets('wide screen: panel carries header from mockup without app bar',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppBar), findsNothing, reason: 'panel does not have its own app bar');
    expect(find.text('2026-08-29 09:15 · 3:27 · ${plL10n.statusDone}'), findsOneWidget,
        reason: 'mockup combines date, duration and status into a single technical line');
    // Date must not appear in the panel a second time on the player card. It remains on the list
    // beside it — there it is the sole description of the recording.
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

  testWidgets('wide screen: selecting another recording updates panel', (tester) async {
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

  testWidgets('narrow screen: tapping card opens separate route as before',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(412, 892));

    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pumpAndSettle();

    expect(routes.pushes, 1, reason: 'without panel, details must go full screen');
    expect(find.byType(RecordingDetailScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget, reason: 'full screen has app bar with back button');
    expect(container.read(selectedRecordingProvider), isNull,
        reason: 'narrow layout does not touch selection provider');

    await unmount(tester);
  });

  testWidgets('wide screen: panel header carries recording title', (tester) async {
    await insert('a', title: 'Standup i przesuniecie release');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Standup i przesuniecie release'));
    await tester.pump();
    await tester.pump();

    // Card in list and panel header show the same title — hence two matches.
    expect(find.text('Standup i przesuniecie release'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(RecordingDetailView),
        matching: find.text('Standup i przesuniecie release'),
      ),
      findsOneWidget,
      reason: 'desktop mockup places title in panel header',
    );
    expect(find.text(plL10n.detailTitle), findsNothing);

    await unmount(tester);
  });

  testWidgets('wide screen: panel without title keeps generic title',
      (tester) async {
    await insert('a');
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(RecordingDetailView),
        matching: find.text(plL10n.detailTitle),
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('wide screen: panel also has "+ tag" chip and close icons on chips',
      (tester) async {
    await insert('a');
    await db.setTags('a', ['spotkanie']);
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(RecordingDetailView),
        matching: find.byType(AddTagChip),
      ),
      findsOneWidget,
      reason: 'manual tag editing works in both detail contexts',
    );
    expect(find.byIcon(Symbols.close_rounded), findsOneWidget,
        reason: 'close icon only on chip in panel, not on card chip in list');

    await unmount(tester);
  });

  testWidgets('GUARD: deleting last occurrence of tag with active filter',
      (tester) async {
    // Filter chip is driven by library stream, so removal of tag from last recording
    // must be accompanied by filter chip disappearance. The filter itself remains active, so the list shows
    // empty search state — and chip row retains only "All", so that
    // this non-existent filter can be cleared.
    await insert('a');
    await db.setTags('a', ['spotkanie']);
    await pumpLibrary(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Transkrypt nagrania a'));
    await tester.pump();
    await tester.pump();

    container.read(tagFilterProvider.notifier).state = 'spotkanie';
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(RecordingCard),
        matching: find.text('Transkrypt nagrania a'),
      ),
      findsOneWidget,
      reason: 'with filter on this tag the recording is still in the list',
    );

    await tester.tap(find.descendant(
      of: find.byType(RecordingDetailView),
      matching: find.byIcon(Symbols.close_rounded),
    ));
    await tester.pump();
    // See comment on delete test: real database I/O in fake-async zone
    // executes via drift operation ordering, not timeouts.
    for (var i = 0; i < 20 && find.text(plL10n.libraryEmptyNoResults).evaluate().isEmpty; i++) {
      await db.getRecording('a');
      await tester.pump();
    }

    expect(find.text(plL10n.libraryEmptyNoResults), findsOneWidget);
    expect(find.text(plL10n.libraryEmptyNoRecordings), findsNothing,
        reason: 'library is not empty, filter result is empty');
    expect(find.text('spotkanie'), findsNothing, reason: 'filter chip disappears with tag');
    expect(find.text(plL10n.libraryFilterAll), findsOneWidget,
        reason: 'without this chip one cannot clear a filter that no longer matches anything');
    expect(find.byType(RecordingDetailView), findsOneWidget,
        reason: 'panel remains alive, recording did not disappear');

    await unmount(tester);
  });
}
