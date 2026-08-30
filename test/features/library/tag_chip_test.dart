import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikro/features/library/library_styles.dart';

import '../../support/l10n_harness.dart';

void main() {
  // STRAZNIK: chip taga przylega do tresci (makieta: inline flex, padding 0 12).
  // Container z alignment przy ograniczonych constraints rozszerza sie na cala
  // dostepna szerokosc — ten test pali sie, gdyby ktos to przywrocil.
  testWidgets('chip taga przylega do tresci zamiast zajmowac cala szerokosc',
      (tester) async {
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: SizedBox(
          width: 412,
          child: Wrap(
            children: [
              TagChip(label: 'release', onDelete: () {}),
              const TagChip(label: 'baza danych', dense: true),
            ],
          ),
        ),
      ),
    ));

    // Progi z zapasem na testowy font (glify 1 em sa szersze niz realne Roboto);
    // wazna jest odleglosc od pelnych 412 px Wrapa, nie dokladna szerokosc.
    final wide = tester.getSize(find.byType(TagChip).first);
    final denseChip = tester.getSize(find.byType(TagChip).last);

    expect(wide.width, lessThan(220),
        reason: 'chip "release" z krzyzykiem ma przylegac do tresci, '
            'nie zajmowac calej szerokosci Wrapa');
    expect(denseChip.width, lessThan(220),
        reason: 'gesty chip karty ma przylegac do tresci');
    expect(wide.height, 32);
    expect(denseChip.height, 26);

    // Najmocniejszy sygnal przylegania: oba chipy mieszcza sie obok siebie
    // w jednym wierszu Wrapa. Chip na 100% szerokosci zepchnalby drugi nizej.
    final firstTop = tester.getTopLeft(find.byType(TagChip).first).dy;
    final lastTop = tester.getTopLeft(find.byType(TagChip).last).dy;
    expect(firstTop, lastTop,
        reason: 'chipy przylegajace do tresci stoja w jednym wierszu');
  });
}
