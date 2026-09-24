import 'dart:async';

import 'package:flutter/widgets.dart';

/// Text field state kept in sync with a value stored in the database, saved automatically.
///
/// Two directions, and the whole difficulty is keeping them from fighting:
/// - user → database: every change restarts a short timer, and the text is written once typing
///   pauses ([flush] also runs on dispose, so leaving the screen never drops the last keystrokes);
/// - database → field ([syncFrom]): a value that changed elsewhere (regeneration, another view)
///   replaces the field content — but ONLY while nothing local is pending. Otherwise the stream
///   echoing an older save would overwrite what the user has typed since.
class SyncedText {
  SyncedText({required this.save, this.onError, this.delay = const Duration(milliseconds: 600)}) {
    controller.addListener(_changed);
  }

  final Future<void> Function(String text) save;
  final void Function(Object error)? onError;
  final Duration delay;

  final controller = TextEditingController();

  /// Last text known to be in the database — written by us or received from [syncFrom].
  String? _stored;
  Timer? _timer;
  int _inFlight = 0;

  bool get _busy => (_timer?.isActive ?? false) || _inFlight > 0;

  /// Adopts [value] from the database unless a local edit is pending or being written.
  void syncFrom(String value) {
    if (_busy || value == _stored) return;
    _stored = value;
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _changed() {
    // Listener also fires on selection moves and on [syncFrom] itself; only real text changes
    // are worth a write.
    if (controller.text == _stored) return;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final text = controller.text;
    if (_stored == null || text == _stored) return;
    _stored = text;
    _inFlight++;
    try {
      await save(text);
    } catch (e) {
      onError?.call(e);
    } finally {
      _inFlight--;
    }
  }

  /// Writes a pending edit, then releases the controller. The write is not awaited by the caller
  /// (State.dispose is synchronous) — it finishes on its own against the captured database.
  void dispose() {
    unawaited(flush());
    controller.removeListener(_changed);
    controller.dispose();
  }
}
