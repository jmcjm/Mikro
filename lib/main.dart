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
  final appDir = await getApplicationSupportDirectory();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    baseDirProvider.overrideWithValue(appDir),
  ]);
  final pipeline = container.read(pipelineProvider);
  final connectivity = container.read(connectivityServiceProvider);
  // Resuming on network reconnect is hooked up during bootstrap, not in pipelineProvider —
  // providers is a shared file across multiple concurrent workflows, and this binding belongs
  // to application startup anyway, just like resumePending below.
  //
  // Two calls because they handle two different concerns: resumePending picks up in-flight
  // statuses (recorded/transcribing/tagging) regardless of network connectivity, while
  // watchConnectivity reconciles connectivity state and retries network errors — which are
  // gated by connectivity.
  pipeline.resumePending();
  pipeline.watchConnectivity(
    onlineChanges: connectivity.onlineChanges,
    isOnline: connectivity.isOnline,
  );
  runApp(UncontrolledProviderScope(container: container, child: const MikroApp()));
}
