import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nagranie pokazywane w panelu szczegolow na szerokim ekranie; `null` znaczy "nic nie
/// wybrano" i panel stoi pusty.
///
/// Na waskim ekranie ten provider nie jest w ogole uzywany — tam szczegoly otwieraja sie
/// przez Navigator.push, bo panelu nie ma gdzie postawic. Dlatego jego stan nie musi
/// przezywac zmiany rozmiaru okna i nie probujemy go z niczym synchronizowac.
class SelectedRecordingController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String recordingId) => state = recordingId;

  void clear() => state = null;
}

final selectedRecordingProvider =
    NotifierProvider<SelectedRecordingController, String?>(SelectedRecordingController.new);
