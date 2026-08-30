import 'dart:math';

import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../db/database.dart';

class SearchService {
  static const threshold = 55;

  List<RecordingWithTags> search(List<RecordingWithTags> all, {String query = '', String? tag}) {
    var items = all;
    if (tag != null) {
      items = items.where((r) => r.tags.contains(tag)).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    final scored = <(RecordingWithTags, int)>[];
    for (final item in items) {
      final transcript = item.recording.transcript?.toLowerCase() ?? '';
      final tagText = item.tags.join(' ');
      final score = max(
        transcript.isEmpty ? 0 : tokenSetRatio(q, transcript),
        tagText.isEmpty ? 0 : tokenSetRatio(q, tagText),
      );
      if (score >= threshold) scored.add((item, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }
}
