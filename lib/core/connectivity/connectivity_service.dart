import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Abstrakcja nad pluginem lacznosci. Dzieki niej pipeline i testy nie zaleza od
/// `connectivity_plus` — w testach wystarczy zwykly `StreamController<bool>`.
abstract class ConnectivityService {
  /// Emituje `true`, gdy urzadzenie ma jakiekolwiek polaczenie sieciowe.
  Stream<bool> get onlineChanges;

  Future<bool> isOnline();
}

class PluginConnectivityService implements ConnectivityService {
  PluginConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Plugin zwraca liste interfejsow, bo urzadzenie moze miec kilka naraz (np. wifi + VPN).
  /// Dla nas liczy sie tylko to, czy jest cokolwiek poza [ConnectivityResult.none].
  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// Wystawione dla testow: sama regula "online" bez dotykania platformy.
  @visibleForTesting
  static bool debugIsOnline(List<ConnectivityResult> results) => _isOnline(results);

  @override
  Stream<bool> get onlineChanges =>
      // distinct() tlumi powtorki w rodzaju wifi -> wifi+VPN, ktore dla nas sa tym samym
      // stanem — pipeline i tak reaguje wylacznie na zbocze, ale mniej szumu w strumieniu
      // to mniej niespodzianek dla przyszlego bannera.
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  @override
  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => PluginConnectivityService());

/// Biezacy stan lacznosci dla UI.
final onlineProvider =
    StreamProvider<bool>((ref) => ref.watch(connectivityServiceProvider).onlineChanges);

/// Ile nagran czeka na przetworzenie: niedokonczone plus wstrzymane brakiem sieci.
/// Zasila przyszly banner informujacy o nagraniach czekajacych w kolejce offline.
final queueLengthProvider =
    StreamProvider<int>((ref) => ref.watch(databaseProvider).watchQueueLength());
