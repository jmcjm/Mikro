import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recording displayed in the side detail panel on wide layouts; `null` means "nothing selected"
/// and the panel shows an empty placeholder.
///
/// On narrow layouts this provider is not used — details open via Navigator.push because there is
/// no room for a side panel. Therefore its state does not need to survive window resize transitions.
class SelectedRecordingController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String recordingId) => state = recordingId;

  void clear() => state = null;
}

final selectedRecordingProvider =
    NotifierProvider<SelectedRecordingController, String?>(SelectedRecordingController.new);
