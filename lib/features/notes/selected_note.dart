import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note shown in the right column of the wide notes layout — the notes counterpart of
/// [selectedRecordingProvider]. Unused on narrow layouts, where notes open as a route.
class SelectedNoteController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String noteId) => state = noteId;

  void clear() => state = null;
}

final selectedNoteProvider = NotifierProvider<SelectedNoteController, String?>(
  SelectedNoteController.new,
);
