import 'package:record/record.dart';

/// Recording abstraction so the platform backend can be swapped
/// without touching the controller (see design spec, risk #1).
abstract class MikroRecorder {
  String get fileExtension;
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> stop();
  Stream<double> amplitude();

  /// Releases the underlying platform recording session.
  /// The instance is unusable afterwards.
  Future<void> dispose();
}

class RecordPluginRecorder implements MikroRecorder {
  final AudioRecorder _record = AudioRecorder();

  @override
  String get fileExtension => 'm4a';

  @override
  Future<bool> hasPermission() => _record.hasPermission();

  @override
  Future<void> start(String path) => _record.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, numChannels: 1),
        path: path,
      );

  @override
  Future<void> stop() async {
    await _record.stop();
  }

  @override
  Stream<double> amplitude() => _record
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .map((a) => ((a.current + 45) / 45).clamp(0.0, 1.0));

  @override
  Future<void> dispose() => _record.dispose();
}
