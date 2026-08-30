import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final docsDir = await getApplicationDocumentsDirectory();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    baseDirProvider.overrideWithValue(docsDir),
  ]);
  final pipeline = container.read(pipelineProvider);
  final connectivity = container.read(connectivityServiceProvider);
  // Wznowienie po powrocie sieci podpinamy w bootstrapie, a nie w pipelineProvider — providers
  // to wspolny plik kilku rownoleglych nurtow pracy, a to wiazanie i tak nalezy do startu
  // aplikacji, tak samo jak resumePending ponizej.
  //
  // Dwa wywolania, bo dotycza dwoch roznych rzeczy: resumePending podnosi statusy in-flight
  // (recorded/transcribing/tagging) niezaleznie od sieci, a watchConnectivity uzgadnia stan
  // lacznosci i wznawia bledy sieciowe — te sa bramkowane lacznoscia.
  pipeline.resumePending();
  pipeline.watchConnectivity(
    onlineChanges: connectivity.onlineChanges,
    isOnline: connectivity.isOnline,
  );
  runApp(UncontrolledProviderScope(container: container, child: const MikroApp()));
}
