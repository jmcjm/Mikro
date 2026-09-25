import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_errors.dart';
import '../../core/db/database.dart';
import '../../core/notes/note_service.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../core/util/synced_text.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_styles.dart';
import '../library/recording_detail_screen.dart';
import '../library/recording_error.dart';
import '../library/selected_recording.dart';
import '../shell/home_tab.dart';
import '../translation/translation_widgets.dart';
import 'selected_note.dart';

/// Standalone note route for narrow layouts.
class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) => NoteView(noteId: noteId);
}

/// Note in preview (rendered Markdown) or edit (raw Markdown) mode, with a link back to the
/// recording it was made from. [panel] mirrors [DetailChrome]: route with app bar vs right column
/// of the wide notes layout.
class NoteView extends ConsumerStatefulWidget {
  const NoteView({super.key, required this.noteId, this.panel = false});

  final String noteId;
  final bool panel;

  @override
  ConsumerState<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends ConsumerState<NoteView> {
  late final AppDatabase _db;
  late final SyncedText _title;
  late final SyncedText _content;

  /// Fresh notes open in preview — the point of generating them is a readable result, editing
  /// is the exception.
  bool _editing = false;
  bool _regenerating = false;
  bool _translating = false;

  /// Language code of the translation shown instead of the note; `null` shows the note.
  String? _shownLanguage;

  @override
  void initState() {
    super.initState();
    // Captured once: the pending write in [SyncedText.dispose] runs after this State is gone,
    // when reading `ref` is no longer allowed.
    _db = ref.read(databaseProvider);
    void failed(Object _) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).noteSaveError)));
    }

    _title = SyncedText(
      save: (text) => _db.updateNote(widget.noteId, title: text, now: DateTime.now()),
      onError: failed,
    );
    _content = SyncedText(
      save: (text) => _db.updateNote(widget.noteId, content: text, now: DateTime.now()),
      onError: failed,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final selection = widget.panel ? ref.read(selectedNoteProvider.notifier) : null;
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.noteDeleteTitle,
      l10n.noteDeleteMessage,
      l10n.detailDelete,
    );
    if (!confirmed || !mounted) return;
    await _db.deleteNote(widget.noteId);
    if (!mounted) return;
    if (selection != null) {
      selection.clear();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _regenerate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      l10n.noteRegenerateTitle,
      l10n.noteRegenerateMessage,
      l10n.detailRegenerateConfirm,
    );
    if (!confirmed || !mounted) return;
    // Pending local edits are written first, otherwise their delayed save would land on top
    // of the regenerated text.
    await Future.wait([_title.flush(), _content.flush()]);
    if (!mounted) return;
    final service = ref.read(noteServiceProvider);
    setState(() => _regenerating = true);
    try {
      await service.regenerate(widget.noteId);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(noteErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  /// Translates the note as it is NOW (pending edits written first) and shows the result.
  Future<void> _translate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(translationServiceProvider);
    final language = await pickTranslationLanguage(context, last: service.lastLanguage);
    if (language == null || !mounted) return;
    setState(() => _translating = true);
    try {
      await Future.wait([_title.flush(), _content.flush()]);
      await service.translateNote(widget.noteId, language);
      if (mounted) {
        setState(() {
          _shownLanguage = language;
          _editing = false;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(noteErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _deleteTranslation(Translation t) async {
    if (_shownLanguage == t.language) setState(() => _shownLanguage = null);
    await _db.deleteTranslation(t.id);
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).detailCancel),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return result == true;
  }

  /// Wide layout keeps the user in the two-pane world: the library tab with the recording
  /// selected. Narrow layout pushes the recording route on top of the note.
  void _openSource(String recordingId) {
    if (widget.panel) {
      ref.read(selectedRecordingProvider.notifier).select(recordingId);
      ref.read(homeTabProvider.notifier).select(HomeTab.library);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RecordingDetailScreen(recordingId: recordingId)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notes = ref.watch(notesStreamProvider);
    final note = notes.value?.where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) {
      final child = notes.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(l10n.noteDeleted));
      return widget.panel ? child : Scaffold(appBar: AppBar(), body: child);
    }
    _title.syncFrom(note.title);
    _content.syncFrom(note.content);

    final actions = _actions(note);
    if (widget.panel) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _meta(note)),
                ...actions,
              ],
            ),
            const SizedBox(height: 8),
            _titleField(fontSize: 28),
            const SizedBox(height: 12),
            Expanded(child: _bodyWithTranslations(note)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, fill: 1),
          tooltip: l10n.detailBackTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _meta(note),
            const SizedBox(height: 4),
            _titleField(fontSize: 24),
            const SizedBox(height: 12),
            Expanded(child: _bodyWithTranslations(note)),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(Note note) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return [
      TranslateButton(busy: _translating, color: scheme.onSurfaceVariant, onPressed: _translate),
      if (note.recordingId != null)
        _regenerating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : IconButton(
                icon: Icon(Symbols.autorenew_rounded, fill: 1, color: scheme.onSurfaceVariant),
                tooltip: l10n.noteRegenerateTooltip,
                onPressed: _regenerate,
              ),
      IconButton(
        icon: Icon(
          _editing ? Symbols.visibility_rounded : Symbols.edit_rounded,
          fill: 1,
          color: scheme.onSurfaceVariant,
        ),
        tooltip: _editing ? l10n.notePreviewTooltip : l10n.noteEditTooltip,
        onPressed: () {
          // Leaving edit mode writes immediately, so the preview never renders stale text.
          if (_editing) _content.flush();
          setState(() {
            _editing = !_editing;
            // A translation is read-only: editing always means editing the note itself.
            if (_editing) _shownLanguage = null;
          });
        },
      ),
      IconButton(
        icon: Icon(Symbols.delete_rounded, fill: 1, color: scheme.onSurfaceVariant),
        tooltip: l10n.detailDeleteTooltip,
        onPressed: _delete,
      ),
    ];
  }

  /// Date line plus the link to the source recording.
  Widget _meta(Note note) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final recordingId = note.recordingId;
    final recording = recordingId == null
        ? null
        : ref
              .watch(recordingsStreamProvider)
              .value
              ?.where((r) => r.recording.id == recordingId)
              .firstOrNull
              ?.recording;
    final muted = monoStyle(size: 13, color: scheme.onSurfaceVariant);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(formatDateTime(note.updatedAt), style: muted),
        if (recordingId == null)
          Text(l10n.noteSourceDeleted, style: muted)
        else
          ActionChip(
            avatar: Icon(Symbols.graphic_eq_rounded, size: 18, color: scheme.primary),
            label: Text(
              l10n.noteSourceLink(
                recording?.title ??
                    (recording == null ? l10n.detailTitle : formatDateTime(recording.createdAt)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => _openSource(recordingId),
          ),
      ],
    );
  }

  Widget _titleField({required double fontSize}) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _title.controller,
      maxLines: null,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration.collapsed(hintText: AppLocalizations.of(context).noteTitleHint),
    );
  }

  Widget _bodyWithTranslations(Note note) {
    final translations = ref.watch(noteTranslationsProvider(widget.noteId)).value ?? const [];
    final shown = translations.where((t) => t.language == _shownLanguage).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TranslationSwitcher(
          translations: translations,
          selected: shown?.language,
          onSelect: (language) => setState(() {
            _shownLanguage = language;
            if (language != null) _editing = false;
          }),
          onDelete: _deleteTranslation,
        ),
        Expanded(child: _body(translation: shown?.content)),
      ],
    );
  }

  Widget _body({String? translation}) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: translation != null
          ? _markdown(translation)
          : _editing
          ? TextField(
              controller: _content.controller,
              autofocus: true,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: monoStyle(size: 14, color: scheme.onSurface).copyWith(height: 1.5),
              decoration: InputDecoration.collapsed(hintText: l10n.noteContentHint),
            )
          : ListenableBuilder(
              listenable: _content.controller,
              builder: (context, _) => _markdown(_content.controller.text),
            ),
    );
  }

  Widget _markdown(String data) {
    final scheme = Theme.of(context).colorScheme;
    return Markdown(
      data: data,
      selectable: true,
      padding: EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
        listBullet: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
        h1: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: scheme.onSurface),
        h2: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
        h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        code: monoStyle(
          size: 14,
          color: scheme.onSurface,
        ).copyWith(backgroundColor: scheme.surfaceContainerHigh),
      ),
    );
  }
}

/// Localized message for a failed note generation. Reuses the recording error texts — the API
/// failure modes are the same ones.
String noteErrorText(AppLocalizations l10n, Object error) => switch (error) {
  NoConfigException() => l10n.pipelineErrorNoConfig,
  MikroApiException(:final kind, :final message) => recordingErrorText(
    l10n,
    kind: kind.name,
    detail: message,
  ),
  _ => l10n.pipelineErrorUnexpected('$error'),
};
