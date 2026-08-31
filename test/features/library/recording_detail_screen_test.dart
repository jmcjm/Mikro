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
import 'package:mikro/features/library/playback.dart';
import 'package:mikro/features/library/recording_detail_screen.dart';
import 'package:mikro/l10n/app_localizations_en.dart';

import '../../support/l10n_harness.dart';

/// Global audioplayers layer without platform channel. The key aspect is that this is
/// a DIFFERENT instance than before: `ensureInitialized` compares it with stored instance and upon
/// change re-runs initialization in the current test zone. Additionally `init`
/// returns immediately, without a platform channel round trip.
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

/// Error with predictable toString: banner constructs message directly from it, so the test can
/// match the whole string instead of searching for a fragment.
class _FakeDbError {
  @override
  String toString() => 'baza padla';
}

void main() {
  late AppDatabase db;

  /// Log of player channel calls in the order the screen sent them. Seek and speed
  /// tests check here: this is the only place showing HOW MANY TIMES
  /// the card actually moved the player.
  final playerCalls = <MethodCall>[];

  setUp(() {
    playerCalls.clear();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Global initialization of audioplayers runs ONCE per process, and the Completer awaited
    // by every player command stays in the zone of whichever test ran it first. In every
    // subsequent test that future is completed, but its continuations go to
    // the dead zone queue — nobody drives them, so seek or setPlaybackRate never
    // reaches the channel. A fresh global platform interface forces re-initialization,
    // in the current test zone. Without this, every player command test would have
    // to be first in the file.
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

  /// audioplayers has no implementation in the test environment: AudioPlayer constructor calls
  /// `init` on the global channel and subscribes to its event stream. Without stubbing these
  /// calls return as MissingPluginException — sometimes after the test ends, creating
  /// flaky failures depending on machine load.
  ///
  /// The stub records calls to [playerCalls] and FAILS or EMULATES seek confirmation. The latter
  /// is crucial: `AudioPlayer.seek` waits for `audio.onSeekComplete` event from
  /// the player event channel and without it hangs until its timeout, leaving
  /// a ticking timer in the test. The event channel includes the player ID in its name, so
  /// we stub it once that ID arrives in the `create` call.
  /// [confirmSeek] controls whether the emulated native layer confirms seeks. Setting to
  /// `false` mimics a platform that accepts seek silently — the only path testing
  /// if the card avoids phantom position.
  void stubAudioPlayers(WidgetTester tester, {bool confirmSeek = true}) {
    final messenger = tester.binding.defaultBinaryMessenger;
    MockStreamHandlerEventSink? playerEvents;

    void stubPlayerEvents(String playerId) {
      final channel = EventChannel('xyz.luan/audioplayers/events/$playerId');
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(onListen: (_, sink) {
          // Block body, not arrow: `inline` encodes return value as channel response,
          // and sink cannot pass through it.
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
            // Source readiness is reported by a separate event; `setSource` waits for it and without it
            // hangs until its own timeout.
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
    // First frame is still drift stream loading state, second frame carries data.
    await tester.pump();
    await tester.pump();
  }

  /// See comment on identical helper in library_screen_test.dart — unmounting
  /// allows drift to fire the timer unregistering from the stream before test teardown.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('done recording: header, transcript card and model caption',
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

  testWidgets('full screen header carries recording title', (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.setTitle('a', 'Standup i przesuniecie release');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.text('Standup i przesuniecie release'), findsOneWidget);
    expect(find.text(plL10n.detailTitle), findsNothing,
        reason: 'generic title gives way to title when recording has one');

    await unmount(tester);
  });

  testWidgets('header without title keeps generic title', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.detailTitle), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('without transcript screen shows progress and status label', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.transcribing);

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.statusTranscribing), findsNWidgets(2)); // badge and caption under spinner
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Without transcript there is nothing to share or copy.
    expect(find.byIcon(Symbols.share_rounded), findsNothing);
    expect(find.byIcon(Symbols.content_copy_rounded), findsNothing);

    await unmount(tester);
  });

  testWidgets('processing error: message and retry', (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'Limit 25 MB');

    await pumpDetail(tester, 'a');

    expect(find.text(plL10n.statusError), findsOneWidget);
    expect(find.text('Limit 25 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, plL10n.detailRetryProcessing), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('deleted recording disappears from screen with message', (tester) async {
    await pumpDetail(tester, 'nie-ma-takiego');

    expect(find.text(plL10n.detailRecordingDeleted), findsOneWidget);

    await unmount(tester);
  });

  /// Overrides the entire recordings stream to place the screen in a state drift
  /// cannot produce in test: database failure or a stream that has emitted nothing yet.
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

  testWidgets('database failure reports error rather than deletion message',
      (tester) async {
    await pumpWithStream(
        tester, Stream<List<RecordingWithTags>>.error(_FakeDbError()));

    expect(find.text(plL10n.libraryDatabaseError('baza padla')), findsOneWidget);
    expect(find.text(plL10n.detailRecordingDeleted), findsNothing,
        reason: 'database failure is not the same as user-deleted recording — '
            'deletion message would prompt looking for an entry that is still there');

    await unmount(tester);
  });

  testWidgets('stream without initial value shows progress, not deletion message',
      (tester) async {
    // Stream that never emits: screen remains in loading state.
    final pending = StreamController<List<RecordingWithTags>>();
    addTearDown(pending.close);

    await pumpWithStream(tester, pending.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(plL10n.detailRecordingDeleted), findsNothing,
        reason: 'before stream emits anything, recording existence is unknown');

    await unmount(tester);
  });

  testWidgets('GUARD: without native share sheet sharing copies to clipboard',
      (tester) async {
    // Tests run on Linux where share_plus would construct `mailto:` and hand it to
    // url_launcher. The screen must fall back to: clipboard plus snackbar.
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

  testWidgets('copying from transcript card preserves message from T12', (tester) async {
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

  testWidgets('GUARD: details with tags and long transcript in mockup window',
      (tester) async {
    // See twin test in library_screen_test.dart — 412x892 window instead of default
    // 800x600 wraps layout like a phone.
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


  // --- manual tag editing: "+ tag" chip and chip deletion ---

  /// Recording ready for viewing. Transcript is essential: without it the transcript card
  /// would spin indefinitely, and `pumpAndSettle` would never return.
  Future<void> insertReady(String id, {List<String> tags = const []}) async {
    await insert(id);
    await db.setTranscript(id, 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
    if (tags.isNotEmpty) await db.setTags(id, tags);
  }

  /// Opens add tag dialog. We pump explicitly instead of `pumpAndSettle` so the test does not
  /// depend on whether any active ticker is in the tree.
  Future<void> openAddTagDialog(WidgetTester tester) async {
    await tester.tap(find.byType(AddTagChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Tag write goes through real database I/O, which in test fake-async zone does not receive
  /// an event loop turn automatically. Drift executes operations sequentially, so a read
  /// queued behind it returns only AFTER write finishes — synchronization via
  /// ordering, not timeouts. See same technique in library_two_pane_test.
  Future<void> settleDb(WidgetTester tester, {required bool Function() until}) async {
    for (var i = 0; i < 20 && !until(); i++) {
      await db.getRecording('a');
      await tester.pump();
    }
  }

  /// Recording tags read via ONE-OFF query. `watchAllWithTags().first` in a widget test
  /// hangs indefinitely: drift stream emission requires an event loop turn
  /// that waiting for `first` will never yield, because in fake-async zone time only advances
  /// during frame pumping.
  Future<List<String>> tagsOf(String id) async {
    final rows = await db.customSelect(
      'SELECT t.name AS name FROM tags t JOIN recording_tags rt ON rt.tag_id = t.id '
      'WHERE rt.recording_id = ? ORDER BY t.name',
      variables: [Variable.withString(id)],
    ).get();
    return [for (final row in rows) row.data['name'] as String];
  }

  testWidgets('tag row has "+ tag" chip that appends tag to recording',
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
        reason: 'name is saved trimmed and lowercased, like model tags');
    expect(find.text('release'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('"+ tag" chip is available also on recording without tags', (tester) async {
    // Without this the first tag cannot be added manually at all.
    await insertReady('a');

    await pumpDetail(tester, 'a');

    expect(find.byType(AddTagChip), findsOneWidget);
    expect(tester.getSize(find.byType(AddTagChip)).height, 32,
        reason: 'mockup gives chip the same height as tag chip');
    expect(
      find.descendant(of: find.byType(AddTagChip), matching: find.byIcon(Symbols.add_rounded)),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('add dialog: empty entry disables confirm button', (tester) async {
    await insertReady('a');

    await pumpDetail(tester, 'a');
    await openAddTagDialog(tester);

    FilledButton confirm() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, plL10n.detailAddTagConfirm));

    expect(confirm().onPressed, isNull, reason: 'empty field has nothing to save');

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(confirm().onPressed, isNull, reason: 'whitespace only is still an empty tag');

    await tester.enterText(find.byType(TextField), 'release');
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await unmount(tester);
  });

  testWidgets('add dialog: duplicate within recording is blocked case-insensitively',
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

  testWidgets('tag chip in details deletes tag immediately without confirmation dialog',
      (tester) async {
    await insertReady('a', tags: ['spotkanie', 'release']);

    await pumpDetail(tester, 'a');

    expect(find.byIcon(Symbols.close_rounded), findsNWidgets(2),
        reason: 'every chip in details has its own close icon');

    await tester.tap(find.descendant(
      of: find.widgetWithText(TagChip, 'spotkanie'),
      matching: find.byIcon(Symbols.close_rounded),
    ));
    await tester.pump();
    await settleDb(tester, until: () => find.text('spotkanie').evaluate().isEmpty);

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'low stakes, reversible via "+ tag"');
    expect(await tagsOf('a'), ['release']);
    expect(find.text('spotkanie'), findsNothing);

    await unmount(tester);
  });

  // --- waveform on player card (D2f) ---

  /// Bar is the only DecoratedBox inside [WaveformBars], so it is counted and measured
  /// directly through it.
  Finder bars() => find.descendant(
        of: find.byType(WaveformBars),
        matching: find.byType(DecoratedBox),
      );

  testWidgets('player card renders bars of saved waveform', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // First three bars have known heights, rest fill the bar to mockup count.
    final levels = <double>[1.0, 0.5, 0.25, ...List.filled(kWaveformBuckets - 4, 0.4), 0.0];
    await insert('a', waveform: encodeWaveform(levels));
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformBars), findsOneWidget);
    expect(tester.getSize(find.byType(WaveformBars)).height, 64,
        reason: 'full amplitude is the entire bar, and on phone card it is 64 px');
    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).levels.length, kWaveformBuckets);

    await unmount(tester);
  });

  testWidgets('recording without saved waveform does not get invented bars',
      (tester) async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformBars), findsNothing,
        reason: 'pre-migration recordings have no envelope and it must not be fabricated');
    // Card must continue to function: transport and timestamps stay in place.
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
    expect(find.text('3:27'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('corrupted waveform data does not crash screen', (tester) async {
    await insert('a', waveform: 'to-nie-jest-json');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformBars), findsNothing);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('header has mockup height', (tester) async {
    await insert('a');

    await pumpDetail(tester, 'a');

    expect(tester.getSize(find.byType(AppBar)).height, 64);

    await unmount(tester);
  });

  // --- waveform as seek surface, 10 s skips, and speed (D2g) ---

  /// Seek positions in the order the screen sent them to the player. Channel stub
  /// is the only place revealing HOW MANY TIMES the card moved it — which is the whole point
  /// of the one-seek-per-gesture discipline.
  List<int> seeks() => [
        for (final call in playerCalls)
          if (call.method == 'seek') (call.arguments as Map)['position'] as int,
      ];

  List<double> rates() => [
        for (final call in playerCalls)
          if (call.method == 'setPlaybackRate')
            (call.arguments as Map)['playbackRate'] as double,
      ];

  /// Player command travels through platform channel round trip, and seeking before
  /// first playback requires two such rounds plus source readiness event. A few frames
  /// allow them all to settle; `pumpAndSettle` is avoided because of potential active tickers in tree.
  Future<void> settlePlayer(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Platform channel method names in the order screen sent them.
  List<String> methods() => [for (final call in playerCalls) call.method];

  /// Recording with full waveform. All bars equal height because these tests verify
  /// played/unplayed split and gestures rather than envelope shape.
  Future<void> insertWithWave(String id) async {
    await insert(id, waveform: encodeWaveform(List.filled(kWaveformBuckets, 0.5)));
    await db.setTranscript(id, 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
  }

  testWidgets('tapping waveform seeks exactly once', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'tap is a single seek, not a series');
    expect(seeks().single, closeTo(207000 / 2, 300),
        reason: 'center of bar is middle of recording');

    await unmount(tester);
  });

  testWidgets('dragging across waveform seeks once at end of gesture', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    final bar = tester.getRect(find.byType(WaveformBars));
    await tester.drag(find.byType(WaveformSeekBar), const Offset(60, 0));
    await settlePlayer(tester);

    expect(seeks().length, 1,
        reason: 'drag tracks cursor only; player moves once at end of gesture');
    expect(seeks().single, closeTo((bar.width / 2 + 60) / bar.width * 207000, 300),
        reason: 'seek targets where finger ended, not where it began');

    await unmount(tester);
  });

  testWidgets('waveform replaces position slider', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformSeekBar), findsOneWidget);
    expect(find.byType(Slider), findsNothing,
        reason: 'redesign seeks along bars, separate slider track is removed');

    await unmount(tester);
  });

  testWidgets('recording without waveform keeps legacy slider', (tester) async {
    await insert('a');
    await db.setTranscript('a', 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus('a', RecordingStatus.done);

    await pumpDetail(tester, 'a');

    expect(find.byType(WaveformSeekBar), findsNothing);
    expect(find.byType(Slider), findsOneWidget,
        reason: 'envelope must not be fabricated, and seeking must remain possible');

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'slider also seeks once at end of gesture');

    await unmount(tester);
  });

  testWidgets('bars divide into played and unplayed by position', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).progress, 0.0,
        reason: 'before seeking progress is 0.0');

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).progress, closeTo(0.5, 0.05),
        reason: 'middle of recording sets progress to around 0.5');

    await unmount(tester);
  });

  testWidgets('waveform indicates progress by dividing bars into played and unplayed', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).played, 0);

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).played, greaterThan(0),
        reason: 'after tapping center the corresponding portion of bars is played');

    await unmount(tester);
  });

  testWidgets('timestamps follow seeking', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    expect(find.text('0:00'), findsOneWidget);

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(find.text('1:43'), findsOneWidget, reason: 'half of 3:27');
    expect(find.text('3:27'), findsOneWidget, reason: 'recording duration does not change');

    await unmount(tester);
  });

  testWidgets('10 s skips respect recording bounds and work without playing',
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
        reason: 'nothing playing, but skip still shifts start position');

    await tapAction(plL10n.detailRewindTooltip);
    expect(seeks(), [10000, 0]);

    await tapAction(plL10n.detailRewindTooltip);
    expect(seeks(), [10000, 0, 0], reason: 'cannot rewind before zero');

    await unmount(tester);
  });

  testWidgets('speed pill cycles label and reports to player', (tester) async {
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
        reason: 'after last step cycle returns to start');

    expect(rates(), [1.25, 1.5, 2.0, 1.0],
        reason: 'each tap reports speed to player without skipping steps');

    await unmount(tester);
  });

  testWidgets('speed label follows UI language', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a', locale: const Locale('en'));

    expect(find.text(AppLocalizationsEn().detailSpeedLabel('1.0')), findsOneWidget,
        reason: 'in English decimal separator is a dot, not a comma');

    await unmount(tester);
  });

  // --- wide layout panel ---

  /// Panel at width it receives right at the wide layout threshold: 840 px window minus
  /// 80 px rail and 400 px list leaves 360 px for it. Transport row must fit in that —
  /// overflowing Row reports error and test fails.
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

  testWidgets('panel: shorter bar, transport row and pill fit at threshold',
      (tester) async {
    await insertWithWave('a');

    await pumpPanel(tester, 'a');

    expect(tester.getSize(find.byType(WaveformBars)).height, 52,
        reason: 'desktop mockup has 52 px bar, shorter than 64 px of phone card');
    expect(find.byTooltip(plL10n.detailRewindTooltip), findsOneWidget);
    expect(find.byTooltip(plL10n.detailForwardTooltip), findsOneWidget);
    expect(find.text(plL10n.detailSpeedLabel('1,0')), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('panel: seeking, skips and speed work as on phone', (tester) async {
    await insertWithWave('a');

    await pumpPanel(tester, 'a');

    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);
    expect(seeks().length, 1);
    expect(seeks().single, closeTo(207000 / 2, 300));

    await tester.tap(find.byTooltip(plL10n.detailForwardTooltip));
    await settlePlayer(tester);
    expect(seeks().last, closeTo(207000 / 2 + 10000, 300),
        reason: 'skip is relative to current cursor position');

    await tester.tap(find.byTooltip(plL10n.detailSpeedTooltip));
    await settlePlayer(tester);
    expect(rates(), [1.25]);
    expect(find.text(plL10n.detailSpeedLabel('1,25')), findsOneWidget,
        reason: 'one speed per screen, same pill as on phone');

    await unmount(tester);
  });

  // --- lazy source loading on seek (fix round 1) ---

  testWidgets('seeking before playback loads source and does not start playback',
      (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(methods(), contains('setSourceUrl'),
        reason: 'without loaded source native layer has nothing to seek — seek '
            'passes with no effect and no confirmation');
    expect(methods().indexOf('setSourceUrl'), lessThan(methods().indexOf('seek')),
        reason: 'source first, seek second');
    expect(methods(), isNot(contains('resume')),
        reason: 'seek gesture does not start playback — pause remains pause');
    expect(seeks().length, 1);
    expect(find.text('1:43'), findsOneWidget, reason: 'position is real, not phantom');
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget,
        reason: 'button still invites playback');

    await unmount(tester);
  });

  testWidgets('10 s skip before playback also loads source', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byTooltip(plL10n.detailForwardTooltip));
    await settlePlayer(tester);

    expect(methods(), contains('setSourceUrl'));
    expect(seeks(), [10000]);
    expect(find.text('0:10'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('playback after seeking resumes instead of reloading source from scratch',
      (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);
    await tester.tap(find.byIcon(Symbols.play_arrow_rounded));
    await settlePlayer(tester);

    expect(methods().where((m) => m == 'setSourceUrl').length, 1,
        reason: 'second source load would wipe newly selected position');
    expect(methods(), contains('resume'));
    expect(methods().lastIndexOf('resume'), greaterThan(methods().indexOf('seek')),
        reason: 'user first chose position, then pressed play');

    await unmount(tester);
  });

  testWidgets('missing seek confirmation does not leave phantom position',
      (tester) async {
    // audioplayers timeout set LONGER than card timeout to avoid leaving a ticking
    // timer after the test. The point is which one clears the phantom: card must do it,
    // not the plugin after its 30 seconds.
    final plugin = AudioPlayer.seekingTimeout;
    AudioPlayer.seekingTimeout = const Duration(seconds: 5);
    addTearDown(() => AudioPlayer.seekingTimeout = plugin);

    await insertWithWave('a');

    await pumpDetail(tester, 'a', confirmSeek: false);
    await tester.tap(find.byType(WaveformSeekBar));
    await settlePlayer(tester);

    expect(seeks().length, 1, reason: 'seek was sent');
    expect(find.text('1:43'), findsOneWidget,
        reason: 'while attempt is pending cursor stays where user put it');

    await tester.pump(const Duration(seconds: 3)); // past card timeout, below plugin timeout

    expect(find.text('0:00'), findsOneWidget,
        reason: 'unconfirmed seek returns to real position immediately — '
            'rather than waiting half a minute for plugin timeout');
    expect(find.text('1:43'), findsNothing);

    // Drain plugin timeout so it does not remain at test end as a ticking timer.
    await tester.pump(const Duration(seconds: 3));

    await unmount(tester);
  });

  // --- smooth waveform animation (user request) ---

  /// Presses transport button and allows commands to reach stub. Playback begins
  /// only after source is loaded, so `pump()` alone would not suffice.
  Future<void> tapTransport(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await settlePlayer(tester);
  }

  /// Number of played bars on waveform.
  int playedCount(WidgetTester tester) =>
      tester.widget<WaveformBars>(find.byType(WaveformBars)).played;

  testWidgets('idle state does not animate', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');

    // Active Ticker holds a registered transient callback for every frame. Counter
    // from binding is thus a direct measure of "is anything animating".
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'recording that is not playing has nothing to interpolate — redundant ticker would force '
            'recalculating card 60 times per second throughout screen lifecycle');

    await unmount(tester);
  });

  testWidgets('ticker starts with playback and stops after pause', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tapTransport(tester, Symbols.play_arrow_rounded);
    // One second for button tap splash to fade: splash is also an animation and
    // counts toward counter; the assertion targets ticker, not Material.
    await tester.pump(const Duration(seconds: 1));

    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'something should animate during playback; that this is OUR ticker rather than '
            'audioplayers position counter alone is proven by cursor movement test below');

    await tapTransport(tester, Symbols.pause_rounded);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.binding.transientCallbackCount, 0,
        reason: 'pause stops ticker rather than merely freezing frame');

    await unmount(tester);
  });

  testWidgets('cursor glides between position events and stops on pause', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tapTransport(tester, Symbols.play_arrow_rounded);

    // Stub sends NO position events, so everything seen below
    // is interpolation — exactly what animation is meant to provide.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);
    final after3s = playedCount(tester);
    expect(after3s, greaterThan(0), reason: 'progress advances along waveform');

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:06'), findsOneWidget);
    expect(playedCount(tester), greaterThan(after3s));

    await tapTransport(tester, Symbols.pause_rounded);
    final frozen = playedCount(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('0:06'), findsOneWidget,
        reason: 'after pause progress stops where it was left — does not rewind to '
            'last position event');
    expect(playedCount(tester), frozen);

    await unmount(tester);
  });

  testWidgets('speed from pill scales interpolation', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip(plL10n.detailSpeedTooltip));
      await settlePlayer(tester);
    }
    expect(find.text(plL10n.detailSpeedLabel('2,0')), findsOneWidget);

    await tapTransport(tester, Symbols.play_arrow_rounded);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('0:02'), findsOneWidget,
        reason: 'at 2.0x one clock second equals two recording seconds');

    await tapTransport(tester, Symbols.pause_rounded);

    await unmount(tester);
  });

  testWidgets('dragging takes precedence over interpolation', (tester) async {
    await insertWithWave('a');

    await pumpDetail(tester, 'a');
    await tapTransport(tester, Symbols.play_arrow_rounded);
    await tester.pump(const Duration(seconds: 1));

    // Finger held in middle of bar: ticker keeps running, but progress stays under finger.
    final bar = tester.getRect(find.byType(WaveformSeekBar));
    final gesture = await tester.startGesture(bar.centerLeft + const Offset(60, 0));
    await gesture.moveBy(Offset(bar.width / 2 - 60, 0));
    await tester.pump();
    final underFinger = playedCount(tester);

    await tester.pump(const Duration(seconds: 1));
    expect(playedCount(tester), underFinger,
        reason: 'during gesture interpolation does not fight finger');

    await gesture.up();
    await settlePlayer(tester);

    await tapTransport(tester, Symbols.pause_rounded);

    await unmount(tester);
  });

  // --- bar breathing during playback (fix round 2) ---

  /// Recording with DESCENDING envelope: first four bars 1.0 / 0.75 / 0.5 / 0.25, rest
  /// in middle. Uniform envelope would not show whether animation preserves shape or blurs it.
  Future<void> insertVariedWave(String id) async {
    final levels = <double>[1.0, 0.75, 0.5, 0.25, ...List.filled(kWaveformBuckets - 4, 0.5)];
    await insert(id, waveform: encodeWaveform(levels));
    await db.setTranscript(id, 'Notatka ze standupu', 'whisper-1');
    await db.updateStatus(id, RecordingStatus.done);
  }

  testWidgets('bars breathe during playback', (tester) async {
    await insertVariedWave('a');

    await pumpDetail(tester, 'a');
    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).beat, isNull,
        reason: 'before playback beat is null');

    await tapTransport(tester, Symbols.play_arrow_rounded);

    final samples = <Duration>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final beat = tester.widget<WaveformBars>(find.byType(WaveformBars)).beat;
      if (beat != null) samples.add(beat);
    }

    expect(samples.toSet().length, greaterThan(6),
        reason: 'beat must change between frames');

    await tapTransport(tester, Symbols.pause_rounded);

    await unmount(tester);
  });

  testWidgets('GUARD: envelope shape is preserved in every frame', (tester) async {
    await insertVariedWave('a');

    await pumpDetail(tester, 'a');
    await tapTransport(tester, Symbols.play_arrow_rounded);

    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 73));
      final beat = tester.widget<WaveformBars>(find.byType(WaveformBars)).beat;
      expect(beat, isNotNull);
      final s = beat!.inMicroseconds / Duration.microsecondsPerSecond;
      final h0 = dancingBarLevel(level: 1.0, elapsedSeconds: s, index: 0);
      final h1 = dancingBarLevel(level: 0.75, elapsedSeconds: s, index: 1);
      final h2 = dancingBarLevel(level: 0.5, elapsedSeconds: s, index: 2);
      final h3 = dancingBarLevel(level: 0.25, elapsedSeconds: s, index: 3);
      expect(h0, greaterThan(h1));
      expect(h1, greaterThan(h2));
      expect(h2, greaterThan(h3));
    }

    await tapTransport(tester, Symbols.pause_rounded);

    await unmount(tester);
  });

  testWidgets('pause restores bars to true heights', (tester) async {
    await insertVariedWave('a');

    await pumpDetail(tester, 'a');
    await tapTransport(tester, Symbols.play_arrow_rounded);

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).beat, isNotNull);

    await tapTransport(tester, Symbols.pause_rounded);

    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).beat, isNull,
        reason: 'after pause envelope is static graph and must stand still');

    await unmount(tester);
  });

  testWidgets('panel: bars breathe same as on phone', (tester) async {
    await insertVariedWave('a');

    await pumpPanel(tester, 'a');
    expect(tester.getSize(find.byType(WaveformBars)).height, 52, reason: 'panel has shorter bar');

    await tapTransport(tester, Symbols.play_arrow_rounded);
    final samples = <Duration>[];
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final beat = tester.widget<WaveformBars>(find.byType(WaveformBars)).beat;
      if (beat != null) samples.add(beat);
    }

    expect(samples.toSet().length, greaterThan(4));

    await tapTransport(tester, Symbols.pause_rounded);
    expect(tester.widget<WaveformBars>(find.byType(WaveformBars)).beat, isNull);

    await unmount(tester);
  });
}
