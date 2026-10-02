import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mic_source.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/providers.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _builtIn = InputDevice(id: '1', label: 'Pixel', type: InputDeviceType.builtIn);
const _sco = InputDevice(id: '7', label: 'Buds', type: InputDeviceType.bluetoothSco);

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('recordConfigFor', () {
    test('headset leaves routing to the plugin, as before the setting existed', () {
      final config = recordConfigFor(MicSource.headset, const [_sco, _builtIn]);
      expect(config.device, isNull);
      expect(config.androidConfig.manageBluetooth, isTrue);
      expect(config.encoder, AudioEncoder.aacLc);
      expect(config.bitRate, 64000);
      expect(config.numChannels, 1);
    });

    test('phone pins the built-in microphone and keeps Bluetooth out of it', () {
      final config = recordConfigFor(MicSource.phone, const [_sco, _builtIn]);
      expect(config.device, _builtIn);
      expect(config.androidConfig.manageBluetooth, isFalse);
    });

    test('phone without a listed built-in microphone lets the system pick', () {
      final config = recordConfigFor(MicSource.phone, const [_sco]);
      expect(config.device, isNull);
      expect(config.androidConfig.manageBluetooth, isFalse);
    });
  });

  group('micSourceProvider', () {
    test('defaults to the headset', () async {
      final container = await _container({});
      expect(container.read(micSourceProvider), MicSource.headset);
    });

    test('persists the choice under a pinned key', () async {
      final container = await _container({});
      await container.read(micSourceProvider.notifier).set(MicSource.phone);
      final prefs = container.read(sharedPrefsProvider);
      expect(prefs.getString('mic_source'), 'phone');

      final reread = await _container({'mic_source': 'phone'});
      expect(reread.read(micSourceProvider), MicSource.phone);
    });

    test('an unknown or mistyped value falls back to the default', () async {
      expect((await _container({'mic_source': 'bogus'})).read(micSourceProvider),
          MicSource.headset);
      expect((await _container({'mic_source': 3})).read(micSourceProvider), MicSource.headset);
    });
  });
}
