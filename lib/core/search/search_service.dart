import 'dart:math';

import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../db/database.dart';

/// Folding Polish diacritical characters to plain ASCII. fuzzywuzzy compares characters
/// strictly 1:1, so the algorithm treats 's' and 'ś' as two completely different letters:
/// query "sledz" against text "śledź" received 22 points instead of 100. Users often type
/// in the search field without diacritics (and transcripts may omit them), so we normalize both sides
/// to a common representation. Uppercase letters are stripped beforehand by `toLowerCase`,
/// so the map only handles lowercase.
const _diacriticFolding = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
};

/// Anything that is not a letter or a digit separates tokens. Unicode character classes instead of [a-z0-9]
/// prevent non-Latin alphabets from breaking into individual characters.
final _tokenSeparator = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

String _normalize(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_diacriticFolding[char] ?? char);
  }
  return buffer.toString();
}

List<String> _tokenize(String normalized) =>
    normalized.split(_tokenSeparator).where((token) => token.isNotEmpty).toList();

/// Best match of a single query token against any text token.
int _bestTokenMatch(String queryToken, List<String> textTokens) {
  var best = 0;
  for (final textToken in textTokens) {
    // Prefix match is an exact hit: user types incrementally and the list should
    // narrow down with each character rather than disappear. Query "mowis" against text "mowisz" gets 100 instead of 91,
    // and two-character "sp" gets 100 instead of 3 points (which would empty the list under any threshold).
    if (textToken.startsWith(queryToken)) return 100;
    // Similarity cannot exceed 2 * min(lengths) / sum of lengths, as that represents the theoretical maximum
    // of shared characters. When this ceiling falls below the current best score or threshold, computing edit distance
    // is a waste of time — on long transcripts this prunes the vast majority of comparisons.
    final ceiling = 200 * min(queryToken.length, textToken.length) ~/
        (queryToken.length + textToken.length);
    if (ceiling <= best || ceiling < SearchService.threshold) continue;
    final score = ratio(queryToken, textToken);
    if (score > best) best = score;
  }
  return best;
}

class SearchService {
  /// Threshold calibrated by benchmark measurements on fuzzywuzzy 1.2.0 (see test guards):
  /// worst single-character typo in a 5-letter word yields 80, whereas pairs
  /// of distinct words that must not match peak around 60 and 56.
  /// 75 sits comfortably between these distributions with safety margins on both sides.
  static const threshold = 75;

  List<RecordingWithTags> search(List<RecordingWithTags> all, {String query = '', String? tag}) {
    var items = all;
    if (tag != null) {
      items = items.where((r) => r.tags.contains(tag)).toList();
    }
    final normalizedQuery = _normalize(query.trim());
    if (normalizedQuery.isEmpty) return items;
    final queryTokens = _tokenize(normalizedQuery);
    if (queryTokens.isEmpty) return items;

    final scored = <(int, RecordingWithTags, int)>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final fields = [
        _normalize(item.recording.transcript ?? ''),
        _normalize(item.tags.join(' ')),
        _normalize(item.recording.title ?? ''),
      ].where((field) => field.isNotEmpty).toList();
      if (fields.isEmpty) continue;

      // Two strategies because they capture different scenarios. tokenSetRatio on the whole field handles
      // queries broader than the text (some query words absent), but completely misses single-word typos:
      // token intersection becomes empty and compares a short string against the entire sorted transcript.
      // The second strategy evaluates token by token, preventing long transcript text from diluting the score.
      var score = 0;
      for (final field in fields) {
        score = max(score, tokenSetRatio(normalizedQuery, field));
      }

      // Combine tokens of all fields into a single pool: e.g. query "groceries milk" should match when
      // "groceries" is a tag and "milk" appears in the transcript. Aggregation by minimum ensures
      // all query words must match — an average would let "milk bicycle" pass on "milk" alone.
      final textTokens = fields.expand(_tokenize).toList();
      var weakestToken = 100;
      for (final queryToken in queryTokens) {
        weakestToken = min(weakestToken, _bestTokenMatch(queryToken, textTokens));
        if (weakestToken <= score) break;
      }
      score = max(score, weakestToken);

      if (score >= threshold) scored.add((index, item, score));
    }
    // Ties are common (prefix match gives 100 to every hit), and Dart's `List.sort` is not
    // stable — without explicit tie-breaking, insertion order (newest first) would shuffle.
    scored.sort((a, b) {
      final byScore = b.$3.compareTo(a.$3);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    return [for (final s in scored) s.$2];
  }
}
