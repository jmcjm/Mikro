import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Which microphone records on Android.
///
/// [headset] is what the app always did: the record plugin hands the input to a connected
/// Bluetooth headset (it opens an SCO link itself) and Android routes a wired or USB headset
/// on its own — with nothing connected that is the phone. [phone] pins the built-in
/// microphone even with a headset on, so the headphones keep playing music in full quality
/// instead of dropping to the call profile.
enum MicSource { headset, phone }

/// Preference key, the on-disk format — renaming it silently resets the choice.
const micSourceKey = 'mic_source';

class MicSourceController extends Notifier<MicSource> {
  @override
  MicSource build() {
    // Untyped read for the same reason as the theme: a value of another type must fall back
    // to the default rather than throw.
    final stored = ref.read(sharedPrefsProvider).get(micSourceKey);
    return MicSource.values.firstWhere(
      (source) => source.name == stored,
      orElse: () => MicSource.headset,
    );
  }

  Future<void> set(MicSource source) async {
    state = source;
    await ref.read(sharedPrefsProvider).setString(micSourceKey, source.name);
  }
}

final micSourceProvider =
    NotifierProvider<MicSourceController, MicSource>(MicSourceController.new);
