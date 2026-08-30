import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/features/library/recording_error.dart';

import '../../support/l10n_harness.dart';

void main() {
  test('kind i detail rowne null -> komunikat zastepczy', () {
    // Wiersz bez rodzaju i bez szczegolu nie niesie o awarii zupelnie nic. Jedyna galaz,
    // w ktorej UI nie ma z czego zlozyc zdania, wiec musi miec swoje.
    expect(recordingErrorText(plL10n), plL10n.errorUnknown);
  });

  test('wiersz sprzed przebudowy: sam detail wraca bez zmian', () {
    // errorKind NULL i gotowe zdanie w errorMessage — tak zapisywaly bledy wersje sprzed
    // rozdzielenia rodzaju od tekstu.
    expect(
      recordingErrorText(plL10n, detail: 'Nagranie przekracza limit 25 MB.'),
      'Nagranie przekracza limit 25 MB.',
    );
  });

  test('ksztalty odpowiedzi lamiace kontrakt maja wlasne zdania, bez wklejanego detalu', () {
    // Regres, przed ktorym stoi ten test: detal tych rodzajow to angielska notka debugowa,
    // ktora nie ma prawa wyladowac w srodku zdania dla uzytkownika.
    for (final kind in [
      ApiErrorKind.badFormat,
      ApiErrorKind.noContent,
      ApiErrorKind.noTranscript,
      ApiErrorKind.badTags,
    ]) {
      final text = recordingErrorText(plL10n, kind: kind.name, detail: 'no text field');
      expect(text, isNot(contains('no text field')), reason: kind.name);
      expect(text, isNot(plL10n.errorUnknown), reason: kind.name);
    }
  });

  test('kod HTTP dalej wchodzi do zdania', () {
    expect(recordingErrorText(plL10n, kind: ApiErrorKind.badResponse.name, detail: 'HTTP 404'),
        contains('HTTP 404'));
  });
}
