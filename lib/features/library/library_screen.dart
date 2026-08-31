import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import '../shell/home_tab.dart';
import 'library_styles.dart';
import 'recording_detail_screen.dart';
import 'recording_error.dart';
import 'selected_recording.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Same breakpoint as side navigation rail — see [wideLayoutBreakpoint]. We measure window size,
    // rather than space remaining after rail, so both switches occur simultaneously.
    final twoPane = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    if (!twoPane) {
      return Scaffold(
        body: SafeArea(bottom: false, child: const _LibraryList(twoPane: false)),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Desktop mockup: list 400 px, separated from detail panel by hairline border.
            Container(
              width: 400,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              ),
              child: const _LibraryList(twoPane: true),
            ),
            const Expanded(child: _DetailPane()),
          ],
        ),
      ),
    );
  }
}

/// Right column of the wide layout.
class _DetailPane extends ConsumerWidget {
  const _DetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRecordingProvider);
    // The mockup does not render content for an unselected state — renders plain surface background
    // until a recording is selected.
    if (selected == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    return RecordingDetailView(
      // Key by id is essential: without it switching recordings would reuse the same
      // State, retaining previous player state and position.
      key: ValueKey(selected),
      recordingId: selected,
      chrome: DetailChrome.panel,
    );
  }
}

/// Recording list: header, search, tag filter, and cards. Occupies full width on narrow screens,
/// sits in left column next to detail panel on wide screens.
class _LibraryList extends ConsumerWidget {
  const _LibraryList({required this.twoPane});

  /// Determines tap behavior: populate adjacent detail panel vs push route.
  final bool twoPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final stream = ref.watch(recordingsStreamProvider);
    final items = ref.watch(filteredRecordingsProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    // An empty list means different things with an active filter (no matching results)
    // vs without filters (empty library) — the UI distinguishes both cases.
    final filtering =
        ref.watch(searchQueryProvider).trim().isNotEmpty || tagFilter != null;

    // Filter bar displays tags from the ENTIRE library, not filtered items.
    // Otherwise selecting a tag would eliminate all other chips, preventing switching filters.
    final allTags = <String>{
      for (final item in stream.value ?? const <RecordingWithTags>[]) ...item.tags,
    }.toList()
      ..sort();

    final selected = ref.watch(selectedRecordingProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.libraryTitle,
                style: TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              const _SearchField(),
              // Row remains visible even if no tags exist in the library while a filter is set —
              // otherwise removing the last chip would eliminate the only way to clear the filter.
              if (allTags.isNotEmpty || tagFilter != null) ...[
                const SizedBox(height: 14),
                _TagFilterBar(tags: allTags, selected: tagFilter),
              ],
            ],
          ),
        ),
        Expanded(
          child: switch (stream) {
            // Stream error must be displayed. Without this branch, database errors would appear
            // as an empty library because filteredRecordingsProvider yields an empty list on error.
            AsyncValue(hasError: true, :final error) =>
              _DatabaseErrorState(message: l10n.libraryDatabaseError('$error')),
            AsyncValue(isLoading: true) =>
              const Center(child: CircularProgressIndicator()),
            _ => items.isEmpty
                ? _EmptyState(filtering: filtering)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => RecordingCard(
                      item: items[i],
                      selected: twoPane && items[i].recording.id == selected,
                      onTap: () => _open(context, ref, items[i].recording.id),
                    ),
                  ),
          },
        ),
      ],
    );
  }

  void _open(BuildContext context, WidgetRef ref, String recordingId) {
    if (twoPane) {
      ref.read(selectedRecordingProvider.notifier).select(recordingId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordingDetailScreen(recordingId: recordingId)),
    );
  }
}

/// Search bar: height 56, radius 28, filled with `surfaceContainer`.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
      style: TextStyle(fontSize: 16, color: scheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintText: AppLocalizations.of(context).librarySearchHint,
        hintStyle: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
        prefixIcon: Icon(Symbols.search_rounded,
            fill: 1, size: 24, color: scheme.onSurfaceVariant),
        // Height 56 is achieved via vertical padding rather than a fixed SizedBox —
        // allowing text field to expand when system accessibility text scaling is active.
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Horizontally scrolling filter chip row: "All" plus tags from the library.
class _TagFilterBar extends ConsumerWidget {
  const _TagFilterBar({required this.tags, required this.selected});

  final List<String> tags;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void select(String? tag) => ref.read(tagFilterProvider.notifier).state = tag;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => i == 0
            ? _FilterChip(
                label: l10n.libraryFilterAll,
                selected: selected == null,
                onTap: () => select(null),
              )
            : _FilterChip(
                label: tags[i - 1],
                selected: selected == tags[i - 1],
                onTap: () => select(tags[i - 1]),
              ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      // Unselected chip renders border outline, selected renders filled background.
      // Material does not accept `shape` and `borderRadius` together, so radius is set on the border shape.
      shape: RoundedRectangleBorder(
        side: selected ? BorderSide.none : BorderSide(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Symbols.check_rounded,
                    fill: 1, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordingCard extends ConsumerWidget {
  const RecordingCard({
    super.key,
    required this.item,
    required this.onTap,
    this.selected = false,
  });

  final RecordingWithTags item;
  final VoidCallback onTap;

  /// Currently selected card in the adjacent panel. Always `false` on narrow screens.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final r = item.recording;
    final failed = r.status == RecordingStatus.error;
    // Error card uses `errorContainer`, so its text switches to
    // `onErrorContainer` — ensuring contrast on red background. Selected card uses
    // `secondaryContainer` per mockup, but errors take precedence: red background conveys
    // essential failure status that selection must not obscure.
    final muted = failed
        ? scheme.onErrorContainer
        : selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;
    final strong = failed
        ? scheme.onErrorContainer
        : selected
            ? scheme.onSecondaryContainer
            : scheme.onSurface;
    // Card body displays title, or falls back to transcript if absent. Recordings prior to schema v4
    // or those without generated titles preserve original appearance. Error cards display the error message
    // even when a title exists. In-progress recordings rely on the status badge and progress bar.
    final body = failed
        ? recordingErrorText(l10n, kind: r.errorKind, detail: r.errorMessage)
        : r.title ?? r.transcript;

    return Material(
      color: failed
          ? scheme.errorContainer
          : selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow,
      // Selected error card is not explicitly drawn in mockup. We add a border outline to ensure
      // selection is visible even on error cards.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: selected && failed
            ? BorderSide(color: scheme.error, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Date yields to status badge when space is constrained under large accessibility fonts.
                  Expanded(
                    child: Text(
                      formatDateTime(r.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoStyle(size: 13, color: muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: r.status),
                ],
              ),
              if (body != null) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w500,
                    color: strong,
                  ),
                ),
              ],
              if (isInProgress(r.status)) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHigh,
                    color: scheme.primary,
                  ),
                ),
              ],
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in item.tags)
                      TagChip(
                        label: tag,
                        dense: true,
                        onTap: () => ref.read(tagFilterProvider.notifier).state = tag,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Symbols.schedule_rounded, fill: 1, size: 18, color: muted),
                  const SizedBox(width: 8),
                  Text(
                    formatDuration(Duration(milliseconds: r.durationMs)),
                    style: tabularStyle(size: 14, color: muted),
                  ),
                  const Spacer(),
                  if (failed)
                    ErrorActionButton(
                      label: l10n.libraryRetry,
                      onPressed: () => ref.read(pipelineProvider).enqueue(r.id),
                    )
                  else if (r.providerUsed != null)
                    Flexible(
                      child: Text(
                        r.providerUsed!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(size: 13, color: muted),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty library state. The message differs when search/filter returns no results vs empty database.
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.filtering});

  final bool filtering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                filtering ? Symbols.search_off_rounded : Symbols.library_music_rounded,
                fill: 1,
                size: 40,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filtering ? l10n.libraryEmptyNoResults : l10n.libraryEmptyNoRecordings,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (!filtering) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  l10n.libraryEmptyDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _RecordCta(
                onTap: () => ref.read(homeTabProvider.notifier).select(HomeTab.recorder),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Call to action from "Empty states and errors" mockup: radius 24, filled with
/// `primaryContainer`, 20 px mic icon leading label.
class _RecordCta extends StatelessWidget {
  const _RecordCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          // Minimum height rather than fixed 48 px allows text scaling on large accessibility fonts.
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.mic_rounded, fill: 1, size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).libraryRecordCta,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Database stream error banner from "Empty states and errors" mockup.
class _DatabaseErrorState extends StatelessWidget {
  const _DatabaseErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.error_rounded, fill: 1, size: 24, color: scheme.error),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
