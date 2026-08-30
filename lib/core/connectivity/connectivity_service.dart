import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Abstrakcja nad pluginem łączności. Dzięki niej pipeline i testy nie zależą od
/// `connectivity_plus` — w testach wystarczy zwykły `StreamController<bool>`.
abstract class ConnectivityService {
  /// Emituje `true`, gdy urządzenie ma jakiekolwiek połączenie sieciowe.
  Stream<bool> get onlineChanges;

  Future<bool> isOnline();
}

class PluginConnectivityService implements ConnectivityService {
  PluginConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Plugin zwraca listę interfejsów, bo urządzenie może mieć kilka naraz (np. wifi + VPN).
  /// Dla nas liczy się tylko to, czy jest cokolwiek poza [ConnectivityResult.none].
  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// Wystawione dla testow: sama regula "online" bez dotykania platformy.
  @visibleForTesting
  static bool debugIsOnline(List<ConnectivityResult> results) => _isOnline(results);

  @override
  Stream<bool> get onlineChanges =>
      // distinct() tłumi powtórki w rodzaju wifi -> wifi+VPN, które dla nas są tym samym
      // stanem — pipeline i tak reaguje wyłącznie na zbocze, ale mniej szumu w strumieniu
      // to mniej niespodzianek dla przyszłego bannera.
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  @override
  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => PluginConnectivityService());

/// Bieżący stan łączności dla UI.
final onlineProvider =
    StreamProvider<bool>((ref) => ref.watch(connectivityServiceProvider).onlineChanges);

/// Ile nagrań czeka na przetworzenie: niedokończone plus wstrzymane brakiem sieci.
/// Zasila przyszły banner „Offline — N nagrań w kolejce".
final queueLengthProvider =
    StreamProvider<int>((ref) => ref.watch(databaseProvider).watchQueueLength());
