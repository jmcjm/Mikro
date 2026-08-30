import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import 'recorder_controller.dart';

class RecorderScreen extends ConsumerWidget {
  const RecorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recorderControllerProvider);
    final controller = ref.read(recorderControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Mikro')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(formatDuration(state.elapsed),
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: state.isRecording ? state.amplitude : 0),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () async {
                if (state.isRecording) {
                  await controller.stopRecording();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Nagranie zapisane — transkrypcja w toku.')));
                  }
                } else {
                  await controller.startRecording();
                }
              },
              child: CircleAvatar(
                radius: 56,
                backgroundColor: state.isRecording ? Colors.red : Colors.deepPurple,
                child: Icon(state.isRecording ? Icons.stop : Icons.mic,
                    size: 56, color: Colors.white),
              ),
            ),
            if (state.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(state.lastError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
