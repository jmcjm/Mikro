import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/features/library/recording_error.dart';

import '../../support/l10n_harness.dart';

void main() {
  test('kind and detail equal null -> fallback message', () {
    // Row without kind and detail carries no failure info. The only branch
    // where UI has nothing to compose a sentence from, so it must use its own.
    expect(recordingErrorText(plL10n), plL10n.errorUnknown);
  });

  test('pre-redesign row: detail alone returns unchanged', () {
    // errorKind NULL and complete sentence in errorMessage — this is how versions before
    // separating kind from text stored errors.
    expect(
      recordingErrorText(plL10n, detail: 'Nagranie przekracza limit 25 MB.'),
      'Nagranie przekracza limit 25 MB.',
    );
  });

  test('contract-breaking response shapes have dedicated messages without pasted detail', () {
    // Regression this test guards against: detail of these kinds is an English debug note,
    // which must not land in the middle of user-facing sentence.
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

  test('HTTP status code is still included in message', () {
    expect(recordingErrorText(plL10n, kind: ApiErrorKind.badResponse.name, detail: 'HTTP 404'),
        contains('HTTP 404'));
  });
}
