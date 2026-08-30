import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import 'recording_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(recordingsStreamProvider);
    final items = ref.watch(filteredRecordingsProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    // Pusta lista znaczy co innego przy aktywnym filtrze (brak trafien), a co innego bez
    // niego (pusta biblioteka) — komunikat musi te dwa przypadki rozrozniac.
    final filtering =
        ref.watch(searchQueryProvider).trim().isNotEmpty || tagFilter != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteka')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Szukaj w transkryptach i tagach…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
          ),
        ),
        if (tagFilter != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InputChip(
                label: Text('tag: $tagFilter'),
                onDeleted: () => ref.read(tagFilterProvider.notifier).state = null,
              ),
            ),
          ),
        Expanded(
          child: switch (stream) {
            // Blad strumienia musi byc widoczny. Bez tej galezi awaria bazy wygladalaby
            // jak pusta biblioteka, bo filteredRecordingsProvider zwraca wtedy pusta liste.
            AsyncValue(hasError: true, :final error) =>
              Center(child: Text('Błąd bazy: $error')),
            AsyncValue(isLoading: true) => const Center(child: CircularProgressIndicator()),
            _ => items.isEmpty
                ? Center(
                    child: Text(filtering
                        ? 'Nic nie znaleziono.'
                        : 'Brak nagrań — nagraj coś.'),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => RecordingCard(item: items[i]),
                  ),
          },
        ),
      ]),
    );
  }
}

class RecordingCard extends ConsumerWidget {
  const RecordingCard({super.key, required this.item});

  final RecordingWithTags item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = item.recording;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _statusIcon(r.status),
        title: Text('${formatDateTime(r.createdAt)} · ${formatDuration(Duration(milliseconds: r.durationMs))}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.status == RecordingStatus.error
                  ? (r.errorMessage ?? 'błąd')
                  : (r.transcript ?? _statusLabel(r.status)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [
                  for (final tag in item.tags)
                    ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(tagFilterProvider.notifier).state = tag,
                    ),
                ],
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RecordingDetailScreen(recordingId: r.id))),
      ),
    );
  }

  Widget _statusIcon(RecordingStatus status) => switch (status) {
        RecordingStatus.done => const Icon(Icons.check_circle, color: Colors.green),
        RecordingStatus.error => const Icon(Icons.error, color: Colors.red),
        _ => const SizedBox(
            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      };

  String _statusLabel(RecordingStatus status) => switch (status) {
        RecordingStatus.recorded => 'w kolejce…',
        RecordingStatus.transcribing => 'transkrypcja…',
        RecordingStatus.tagging => 'tagowanie…',
        _ => '',
      };
}
