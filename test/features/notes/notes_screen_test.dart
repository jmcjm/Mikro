import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/features/notes/note_view.dart';
import 'package:mikro/features/notes/notes_screen.dart';

import '../../support/l10n_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    // Phone width: notes open as a route, not in a side panel.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: localizedApp(home)),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> note(String id, String title, String content, {String? recordingId, DateTime? at}) =>
      db.insertNote(
        id: id,
        recordingId: recordingId,
        title: title,
        content: content,
        now: at ?? DateTime(2026, 9, 1),
      );

  /// Tests run on Linux, where there is no native share sheet and sharing falls back to the
  /// clipboard — so the clipboard is where the shared text can be observed.
  List<String> captureClipboard(WidgetTester tester, {bool failing = false}) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        if (failing) throw PlatformException(code: 'unavailable');
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  testWidgets('short wide screen: the whole note panel scrolls, not just the body',
      (tester) async {
    await note('n1', 'Długa notatka', List.generate(60, (i) => 'Linia numer $i').join('\n\n'));
    // A phone in landscape: two panes, little height.
    tester.view.physicalSize = const Size(915, 412);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: localizedApp(const NotesScreen()),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Długa notatka'));
    await tester.pump();
    await tester.pump();

    final panel = find.byType(NoteView);
    final title = find.descendant(of: panel, matching: find.byType(TextField)).first;
    final top = tester.getTopLeft(title).dy;
    await tester.drag(panel, const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(title).dy, lessThan(top - 200),
        reason: 'the title scrolls away with the body');
    expect(find.text('Linia numer 20'), findsOneWidget, reason: 'the body grows with its text');
    await unmount(tester);
  });

  testWidgets('empty state', (tester) async {
    await pump(tester, const NotesScreen());
    expect(find.text(plL10n.notesEmpty), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('list shows title and a Markdown-free preview; search filters', (tester) async {
    await note('a', 'Standup', '## Ustalenia\n- **deploy** w piątek', at: DateTime(2026, 9, 2));
    await note('b', 'Zakupy', '- [ ] mleko', at: DateTime(2026, 9, 1));
    await pump(tester, const NotesScreen());

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Ustalenia · deploy w piątek'), findsOneWidget);
    expect(find.text('mleko'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mleko');
    await tester.pump();
    expect(find.text('Standup'), findsNothing);
    expect(find.text('Zakupy'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rower');
    await tester.pump();
    expect(find.text(plL10n.notesNoResults), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping a note opens it rendered as Markdown', (tester) async {
    await note('a', 'Standup', '## Ustalenia\n- deploy');
    await pump(tester, const NotesScreen());

    await tester.tap(find.text('Standup'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteView), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Ustalenia'), findsOneWidget, reason: 'heading marker is rendered, not shown');
    await unmount(tester);
  });

  testWidgets('edit mode shows raw Markdown and saves changes', (tester) async {
    await note('a', 'Tytuł', '- punkt');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.edit_rounded));
    await tester.pump();
    final content = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '- punkt',
    );
    expect(content, findsOneWidget);

    await tester.enterText(content, '- punkt\n- drugi');
    // Back to preview flushes immediately.
    await tester.tap(find.byIcon(Symbols.visibility_rounded));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect((await tester.runAsync(() => db.getNote('a')))!.content, '- punkt\n- drugi');
    expect(find.text('drugi'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('title is editable', (tester) async {
    await note('a', 'Stary', 'x');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Stary'),
      'Nowy',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

    expect((await tester.runAsync(() => db.getNote('a')))!.title, 'Nowy');
    await unmount(tester);
  });

  testWidgets('source link names the recording; unlinked note says it was deleted', (tester) async {
    await db.insertRecording(
      id: 'r',
      createdAt: DateTime(2026, 9, 1),
      durationMs: 1000,
      audioPath: '/r.m4a',
    );
    await db.setTitle('r', 'Spotkanie');
    await note('a', 'N', 'x', recordingId: 'r');
    await note('b', 'N2', 'y');

    await pump(tester, const NoteScreen(noteId: 'a'));
    expect(find.text(plL10n.noteSourceLink('Spotkanie')), findsOneWidget);
    await unmount(tester);

    await pump(tester, const NoteScreen(noteId: 'b'));
    expect(find.text(plL10n.noteSourceDeleted), findsOneWidget);
    expect(
      find.byIcon(Symbols.autorenew_rounded),
      findsNothing,
      reason: 'nothing to regenerate from without a source',
    );
    await unmount(tester);
  });

  testWidgets('delete asks for confirmation and closes the note', (tester) async {
    await note('a', 'Do usunięcia', 'x');
    await pump(tester, const NotesScreen());
    await tester.tap(find.text('Do usunięcia'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(plL10n.detailDelete));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byType(NoteView), findsNothing);
    expect(find.text(plL10n.notesEmpty), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('note tags: shown, coloured from the dialog, removable', (tester) async {
    await note('a', 'Standup', 'x');
    await db.addNoteTag('a', 'praca');
    await pump(tester, const NoteScreen(noteId: 'a'));

    expect(find.text('praca'), findsOneWidget);
    await tester.tap(find.text('praca'));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.tagColorTitle('praca')), findsOneWidget);

    // Swatches: default first, then the palette; pick the first real colour.
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(InkResponse)).at(1),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => db.watchTagColors().first), {'praca': 0});

    await tester.tap(find.byTooltip(plL10n.detailRemoveTagTooltip));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('praca'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a stored translation is shown on request, rendered as Markdown', (tester) async {
    await note('a', 'Plan', '- punkt');
    await db.saveTranslation(
      noteId: 'a',
      language: 'en',
      content: '# Plan\n\n- item',
      now: DateTime(2026),
    );
    await pump(tester, const NoteScreen(noteId: 'a'));

    expect(find.text('item'), findsNothing);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('item'), findsOneWidget);
    expect(find.text('punkt'), findsNothing);
    await unmount(tester);
  });

  testWidgets('note colour is picked from the note and stored', (tester) async {
    await note('a', 'Standup', 'x');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byTooltip(plL10n.noteColorTooltip));
    await tester.pumpAndSettle();
    expect(find.text(plL10n.noteColorTitle), findsOneWidget);
    // Swatches: default first, then the palette.
    await tester.tap(find
        .descendant(of: find.byType(AlertDialog), matching: find.byType(InkResponse))
        .at(3));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect((await tester.runAsync(() => db.getNote('a')))!.color, 2);
    await unmount(tester);
  });

  testWidgets('share: the title goes back on top of the body as a Markdown heading', (
    tester,
  ) async {
    final copied = captureClipboard(tester);
    await note('a', 'Plan', '- punkt');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    // The title is stored apart from the body (the heading is split off on generation), so the
    // body alone would lose it.
    expect(copied, ['# Plan\n\n- punkt']);
    expect(find.text(plL10n.detailCopied), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('share: text typed a moment ago is included, before its delayed save lands', (
    tester,
  ) async {
    final copied = captureClipboard(tester);
    await note('a', 'Stary', '- punkt');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.edit_rounded));
    await tester.pump();
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Stary'),
      'Nowy',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '- punkt'),
      '- punkt\n- drugi',
    );
    // No pump with a duration: the 600 ms debounce has not written anything to the database.
    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['# Nowy\n\n- punkt\n- drugi']);
    await unmount(tester);
  });

  testWidgets('share: a note without a title shares just its body', (tester) async {
    final copied = captureClipboard(tester);
    await note('a', '', 'Sama treść');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['Sama treść']);
    await unmount(tester);
  });

  testWidgets('share: a shown translation is shared instead of the note', (tester) async {
    final copied = captureClipboard(tester);
    await note('a', 'Plan', '- punkt');
    await db.saveTranslation(
      noteId: 'a',
      language: 'en',
      content: '# Plan\n\n- item',
      now: DateTime(2026),
    );
    await pump(tester, const NoteScreen(noteId: 'a'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    // The stored translation already carries its own heading (see TranslationService.translateNote).
    expect(copied, ['# Plan\n\n- item']);
    await unmount(tester);
  });

  testWidgets('share: a stored translation that is not shown does not replace the note', (
    tester,
  ) async {
    final copied = captureClipboard(tester);
    await note('a', 'Plan', '- punkt');
    await db.saveTranslation(
      noteId: 'a',
      language: 'en',
      content: '# Plan\n\n- item',
      now: DateTime(2026),
    );
    await pump(tester, const NoteScreen(noteId: 'a'));

    // The translation exists but the note itself is on screen — that is what gets shared.
    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['# Plan\n\n- punkt']);
    await unmount(tester);
  });

  testWidgets('share: spaces around the title are not shared', (tester) async {
    final copied = captureClipboard(tester);
    await note('a', ' Plan ', 'x');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, ['# Plan\n\nx']);
    await unmount(tester);
  });

  testWidgets('share: a note with nothing but whitespace shares nothing', (tester) async {
    final copied = captureClipboard(tester);
    await note('a', '  ', '\n ');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, isEmpty);
    expect(find.text(plL10n.detailCopied), findsNothing);
    await unmount(tester);
  });

  testWidgets('share: a failing clipboard reports an error instead of a confirmation', (
    tester,
  ) async {
    final copied = captureClipboard(tester, failing: true);
    await note('a', 'Plan', '- punkt');
    await pump(tester, const NoteScreen(noteId: 'a'));

    await tester.tap(find.byIcon(Symbols.share_rounded));
    await tester.pump();
    await tester.pump();

    expect(copied, isEmpty);
    expect(find.text(plL10n.detailShareError), findsOneWidget);
    expect(find.text(plL10n.detailCopied), findsNothing);
    await unmount(tester);
  });
}
