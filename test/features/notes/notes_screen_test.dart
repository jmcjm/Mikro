import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
    expect(find.byType(Markdown), findsOneWidget);
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
}
