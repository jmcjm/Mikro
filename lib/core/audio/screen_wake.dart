import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the display on while a recording is in progress. On Android a screen that goes dark
/// sends the app to the background, where the system may cut off microphone access mid-take.
abstract class ScreenWake {
  /// Turns the keep-screen-on lock on or off. Must never throw: a missing lock is an
  /// inconvenience, a failed recording is not.
  Future<void> keepOn(bool on);
}

class WakelockScreenWake implements ScreenWake {
  @override
  Future<void> keepOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Best-effort: no screen-saver service (bare Linux session, sandbox) or no plugin
      // (tests) only means the screen may dim, the recording itself is unaffected.
    }
  }
}
