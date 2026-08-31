import 'dart:convert';

/// Number of waveform bars on the player card. Directly from the design mockup (Mikro-MD3.dc.html,
/// `wave` list generator): 44 bars with 3 px spacing in a 56 px high container.
const int kWaveformBuckets = 44;

/// Reduces an amplitude sample stream (0..1, one every 200 ms) into a fixed number of buckets.
///
/// Each bucket takes the PEAK of its slice because we render an amplitude envelope: the bar
/// should reflect peak loudness in that time slice rather than averaging speech pauses
/// into a flat line. Boundaries are calculated using integer arithmetic
/// (`i * n ~/ buckets`), making bucket partitioning deterministic even when sample count
/// is not evenly divisible by bucket count: the first and last samples always map to
/// the outer buckets.
///
/// Recordings shorter than [buckets] samples (under ~9 s) are stretched: a bucket without its own
/// slice takes the nearest sample. A gap would falsely indicate silence.
List<double> reduceToBuckets(List<double> samples, {int buckets = kWaveformBuckets}) {
  if (samples.isEmpty || buckets <= 0) return const [];
  final n = samples.length;
  final out = <double>[];
  for (var i = 0; i < buckets; i++) {
    final start = i * n ~/ buckets;
    var end = (i + 1) * n ~/ buckets;
    if (end <= start) end = start + 1;
    if (end > n) end = n;
    var peak = 0.0;
    for (var j = start; j < end; j++) {
      final v = samples[j].clamp(0.0, 1.0);
      if (v > peak) peak = v;
    }
    out.add(peak);
  }
  return out;
}

/// Serializes to the `waveform` database column: plain JSON array. Values are rounded to
/// three decimal places — the bar is 56 px high, so additional precision would only
/// bloat database storage (44 x 20 characters instead of 44 x 5).
String encodeWaveform(List<double> buckets) =>
    jsonEncode([for (final b in buckets) (b.clamp(0.0, 1.0) * 1000).round() / 1000]);

/// Deserializes the `waveform` column. Returns null for missing data AND for unparseable
/// content — in which case the UI falls back to an empty state rather than crashing on
/// pre-migration recordings or corrupted rows.
List<double>? decodeWaveform(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (data is! List || data.isEmpty) return null;
  final out = <double>[];
  for (final v in data) {
    if (v is! num || !v.isFinite) return null;
    out.add(v.toDouble().clamp(0.0, 1.0));
  }
  return out;
}
