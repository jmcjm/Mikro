import 'dart:io';

import 'package:record/record.dart';

import 'mic_source.dart';

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

/// Recording parameters for [source], given the input devices the platform reports.
///
/// [MicSource.phone] names the built-in microphone as the preferred device and turns off the
/// plugin's Bluetooth handling — with it on, the plugin would still open an SCO link to a
/// connected headset. When no built-in microphone is listed the device stays unset, so the
/// system picks one rather than recording failing.
RecordConfig recordConfigFor(MicSource source, List<InputDevice> devices) {
  final phone = source == MicSource.phone;
  return RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    numChannels: 1,
    device: phone ? devices.where((d) => d.type == InputDeviceType.builtIn).firstOrNull : null,
    androidConfig: AndroidRecordConfig(manageBluetooth: !phone),
  );
}

class RecordPluginRecorder implements MikroRecorder {
  RecordPluginRecorder({MicSource Function()? micSource})
      : _micSource = micSource ?? (() => MicSource.headset);

  final AudioRecorder _record = AudioRecorder();

  /// Read at every start, so a change in settings applies to the next recording.
  final MicSource Function() _micSource;

  @override
  String get fileExtension => 'm4a';

  @override
  Future<bool> hasPermission() => _record.hasPermission();

  @override
  Future<void> start(String path) async {
    // The choice only exists on Android; elsewhere the system default stays as it was.
    final source = Platform.isAndroid ? _micSource() : MicSource.headset;
    final devices =
        source == MicSource.phone ? await _record.listInputDevices() : const <InputDevice>[];
    await _record.start(recordConfigFor(source, devices), path: path);
  }

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
