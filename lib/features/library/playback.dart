// Playback control logic for the details card. Resides outside widgets to allow
// verification without mounting widgets or native audio player — ensuring
// slider, cursor, and time counters remain perfectly synchronized.

/// Playback rates in cycle order. Four discrete steps because finer increments
/// are barely noticeable and unnecessarily clutter the UI label.
const List<double> kPlaybackRates = [1.0, 1.25, 1.5, 2.0];

/// Step duration for replay_10 and forward_10 skip buttons. Ten seconds directly from mockup icons.
const Duration kSkipStep = Duration(seconds: 10);

/// Next playback rate in the cycle; wraps to the first rate after the last.
///
/// An unknown value falls back to the beginning of the list —
/// the speed pill UI only renders these four discrete rates.
double nextPlaybackRate(double current) {
  final index = kPlaybackRates.indexOf(current);
  if (index < 0) return kPlaybackRates.first;
  return kPlaybackRates[(index + 1) % kPlaybackRates.length];
}

/// Target skip position clamped to recording boundaries for [step] from [from].
///
/// Boundary clamping is performed here rather than in the player because the same calculation feeds the UI:
/// if the UI issued a seek past the end, the native layer would clamp it silently,
/// causing a temporary display mismatch.
///
/// Zero total duration yields Duration.zero.
Duration skipTarget(Duration from, Duration step, Duration total) {
  final totalMs = total.inMilliseconds;
  if (totalMs <= 0) return Duration.zero;
  return Duration(milliseconds: (from.inMilliseconds + step.inMilliseconds).clamp(0, totalMs));
}

/// Number of waveform bars to the left of the cursor, representing played progress.
///
/// Matches the mockup generator formula (`i / count < played`), computed using
/// integer arithmetic to avoid double precision rounding jumps across bar boundaries.
int playedBars({required int count, required Duration position, required Duration total}) {
  final totalMs = total.inMilliseconds;
  if (count <= 0 || totalMs <= 0) return 0;
  final positionMs = position.inMilliseconds.clamp(0, totalMs);
  // Integer division ceiling: count of indices i where i/count < position/total.
  final played = (positionMs * count + totalMs - 1) ~/ totalMs;
  return played.clamp(0, count);
}

/// Position in recording for touch coordinate [dx] on waveform surface of width [width].
///
/// Dragging past waveform boundaries clamps to the edges so drag gestures are not interrupted
/// when the finger moves slightly outside the card.
Duration positionAt({required double dx, required double width, required Duration total}) {
  if (width <= 0 || total <= Duration.zero) return Duration.zero;
  final fraction = (dx / width).clamp(0.0, 1.0);
  return Duration(milliseconds: (total.inMilliseconds * fraction).round());
}

/// Difference threshold above which a position update is considered a seek jump rather than minor drift.
/// 500 ms: position events arrive every 200 ms - 1 s, so minor jitter stays well below,
/// while explicit seeks and loop wraps stay well above.
const Duration kPositionSnap = Duration(milliseconds: 500);

/// Interpolated playback position between events: base timestamp plus elapsed time scaled by speed rate.
///
/// Native players report position events every 200 ms - 1 s. A cursor bound strictly to events
/// stutters; interpolating elapsed time between events provides smooth movement.
///
/// Zero [total] indicates unknown length and removes upper clamping.
Duration interpolatePosition({
  required Duration base,
  required Duration elapsed,
  required double rate,
  required Duration total,
}) {
  // Microseconds precision: a 60 Hz frame is ~16.7 ms, so rounding to milliseconds would drop frames.
  final ms = base.inMilliseconds + (elapsed.inMicroseconds * rate / 1000).round();
  final maxMs = total.inMilliseconds;
  if (ms < 0) return Duration.zero;
  if (maxMs > 0 && ms > maxMs) return total;
  return Duration(milliseconds: ms);
}

/// New interpolation baseline following a position event from player.
///
/// An incoming event can lag slightly behind currently rendered interpolation —
/// rewinding the cursor by a few milliseconds causes visible jitter, so small negative deltas are ignored.
/// Large deltas represent deliberate seeks or end-of-track events and are applied immediately.
Duration reconcilePosition({
  required Duration shown,
  required Duration event,
  Duration snapAbove = kPositionSnap,
}) {
  final delta = event - shown;
  if (delta.abs() > snapAbove) return event;
  return delta.isNegative ? shown : event;
}

/// Bar breathing cycle periods in seconds. Slower than recording screen level bars (~1 s):
/// on the recording screen bars represent dynamic audio meter, here they represent a living waveform chart.
const List<double> kBarDanceSeconds = [2.6, 2.2, 3.1, 2.4, 2.9, 2.3, 2.8, 2.5, 3.0];

/// Negative start delays in seconds. SEVEN delay values paired with NINE periods:
/// the (period, delay) combination repeats only every 63 bars, preventing repetitive patterns in [kWaveformBuckets] bars.
const List<double> kBarDanceDelays = [-2.1, -0.5, -1.3, 0.0, -1.7, -0.9, -0.3];

/// Breathing amplitude depth: bar oscillates between `1 - kBarDanceDepth` and peak waveform height.
///
/// A narrow modulation range is critical: a wide range would turn the static waveform into a fluctuating equalizer,
/// obscuring actual acoustic loudness. At 0.15 depth, relative bar height ordering is preserved across
/// differences greater than 18%, keeping the animated view faithful to the recorded audio envelope.
const double kBarDanceDepth = 0.15;

/// Bar height during playback, normalized 0..1.
///
/// Bar modulates around its true recorded height — scaling by [level] preserves the actual waveform envelope.
///
/// Triangle wave shape based on design mockup keyframes (`@keyframes bar { 0%,100% { scaleY(.25) } 50% { scaleY(1) } }`).
/// Driven by monotonic elapsed playback time without wrapping discontinuities.
double dancingBarLevel({
  required double level,
  required double elapsedSeconds,
  required int index,
}) {
  final period = kBarDanceSeconds[index % kBarDanceSeconds.length];
  final delay = kBarDanceDelays[index % kBarDanceDelays.length];
  final phase = ((elapsedSeconds - delay) / period) % 1.0;
  final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return level.clamp(0.0, 1.0) * (1 - kBarDanceDepth + kBarDanceDepth * wave);
}
