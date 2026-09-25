import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_styles.dart';
import '../shell/home_tab.dart';
import 'note_view.dart';
import 'selected_note.dart';

/// Notes tab: searchable list, and on wide layouts a side panel with the selected note —
/// the same master-detail split as the library.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final twoPane = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    if (!twoPane) {
      return const Scaffold(body: SafeArea(bottom: false, child: _NotesList(twoPane: false)));
    }
    final selected = ref.watch(selectedNoteProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 400,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              ),
              child: const _NotesList(twoPane: true),
            ),
            Expanded(
              child: selected == null
                  ? ColoredBox(color: scheme.surface)
                  // Keyed by id for the same reason as the recording panel: a new note needs
                  // a fresh State, not the previous note's controllers.
                  : NoteView(key: ValueKey(selected), noteId: selected, panel: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.twoPane});

  final bool twoPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final stream = ref.watch(notesStreamProvider);
    final items = ref.watch(filteredNotesProvider);
    final filtering = ref.watch(noteSearchQueryProvider).trim().isNotEmpty;
    final selected = ref.watch(selectedNoteProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notesTitle,
                style: TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) => ref.read(noteSearchQueryProvider.notifier).state = v,
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainer,
                  hintText: l10n.notesSearchHint,
                  hintStyle: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(
                    Symbols.search_rounded,
                    fill: 1,
                    size: 24,
                    color: scheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (stream) {
            AsyncValue(hasError: true, :final error) => Center(
              child: Text(l10n.libraryDatabaseError('$error')),
            ),
            AsyncValue(isLoading: true) => const Center(child: CircularProgressIndicator()),
            _ =>
              items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          filtering ? l10n.notesNoResults : l10n.notesEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => NoteCard(
                        note: items[i],
                        selected: twoPane && items[i].id == selected,
                        onTap: () => _open(context, ref, items[i].id),
                      ),
                    ),
          },
        ),
      ],
    );
  }

  void _open(BuildContext context, WidgetRef ref, String noteId) {
    if (twoPane) {
      ref.read(selectedNoteProvider.notifier).select(noteId);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteScreen(noteId: noteId)));
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap, this.selected = false});

  final Note note;
  final VoidCallback onTap;
  final bool selected;

  /// Card preview: first lines of the body with Markdown markers removed, so the list shows
  /// words rather than `## ` and `- [ ]`.
  static String preview(String markdown) =>
      (markdown.length > 600 ? markdown.substring(0, 600) : markdown)
          .split('\n')
          .map(
            (line) => line.replaceFirst(RegExp(r'^\s*(#+|[-*+]\s*\[[ xX]\]|[-*+>]|\d+\.)\s*'), ''),
          )
          .map((line) => line.replaceAll(RegExp(r'[*_`]'), '').trim())
          .where((line) => line.isNotEmpty)
          .join(' · ');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // The note's colour is an outline, not a fill: a filled card in a saturated colour drowned
    // the text and shouted over the rest of the list. The note view shows it as a dot.
    final mark = AccentPalette.of(context).mark(note.color);
    final muted = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final strong = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: mark == null
            ? BorderSide.none
            : BorderSide(color: mark.withValues(alpha: 0.8), width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDateTime(note.updatedAt),
                      style: monoStyle(size: 12, color: muted),
                    ),
                  ),
                  if (note.recordingId != null)
                    Icon(Symbols.graphic_eq_rounded, size: 16, color: muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.title.isEmpty ? l10n.noteUntitled : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: strong),
              ),
              const SizedBox(height: 4),
              Text(
                preview(note.content),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 20 / 14, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
