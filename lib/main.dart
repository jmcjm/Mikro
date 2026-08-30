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
  // Wznowienie po powrocie sieci podpinamy w bootstrapie, a nie w pipelineProvider — providers
  // są wspólnym plikiem kilku równoległych nurtów pracy, a to wiązanie i tak należy do startu
  // aplikacji, tak samo jak resumePending poniżej.
  pipeline.bindConnectivity(container.read(connectivityServiceProvider).onlineChanges);
  pipeline.resumePending();
  runApp(UncontrolledProviderScope(container: container, child: const MikroApp()));
}
