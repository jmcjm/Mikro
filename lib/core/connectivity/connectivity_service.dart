import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Abstraction over the connectivity plugin. Allows the pipeline and tests to decouple from
/// `connectivity_plus` — tests only need a plain `StreamController<bool>`.
abstract class ConnectivityService {
  /// Emits `true` when the device has any active network connection.
  Stream<bool> get onlineChanges;

  Future<bool> isOnline();
}

class PluginConnectivityService implements ConnectivityService {
  PluginConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// The plugin returns a list of interfaces because a device can have multiple active simultaneously (e.g. WiFi + VPN).
  /// We only care whether there is anything other than [ConnectivityResult.none].
  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// Exposed for testing: pure "online" rule without touching platform channels.
  @visibleForTesting
  static bool debugIsOnline(List<ConnectivityResult> results) => _isOnline(results);

  @override
  Stream<bool> get onlineChanges =>
      // distinct() suppresses duplicate transitions such as WiFi -> WiFi+VPN, which represent the same
      // online state — the pipeline only reacts to rising edges, but reducing stream noise
      // avoids unexpected events for any future UI indicators.
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  @override
  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => PluginConnectivityService());

/// Number of recordings pending processing: in-flight plus paused due to offline status.
/// Feeds the queue banner indicating recordings waiting in the offline queue.
final queueLengthProvider =
    StreamProvider<int>((ref) => ref.watch(databaseProvider).watchQueueLength());
