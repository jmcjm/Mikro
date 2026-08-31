import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikro/features/library/library_styles.dart';

import '../../support/l10n_harness.dart';

void main() {
  // GUARD: tag chip hugs content (mockup: inline flex, padding 0 12).
  // Container with alignment under tight constraints expands to full
  // available width — this test fails if that regression is reintroduced.
  testWidgets('tag chip hugs content instead of expanding to full width',
      (tester) async {
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: SizedBox(
          width: 412,
          child: Wrap(
            children: [
              TagChip(label: 'release', onDelete: () {}),
              const TagChip(label: 'baza danych', dense: true),
              AddTagChip(onTap: () {}),
            ],
          ),
        ),
      ),
    ));

    // Thresholds with buffer for test font (1 em glyphs are wider than real Roboto);
    // what matters is distance from full 412 px Wrap, not exact width.
    final wide = tester.getSize(find.byType(TagChip).first);
    final denseChip = tester.getSize(find.byType(TagChip).last);

    expect(wide.width, lessThan(220),
        reason: '"release" chip with delete icon must hug content, '
            'not occupy full Wrap width');
    expect(denseChip.width, lessThan(220),
        reason: 'dense card chip must hug content');
    expect(wide.height, 32);
    expect(denseChip.height, 26);

    final addChip = tester.getSize(find.byType(AddTagChip));
    expect(addChip.width, lessThan(160),
        reason: '"+ tag" chip must hug content');
    expect(addChip.height, 32);

    // Strongest hug indicator: all three chips fit
    // next to each other in a single Wrap row. A 100% width chip
    // would push the next one to the line below.
    final firstTop = tester.getTopLeft(find.byType(TagChip).first).dy;
    final lastTop = tester.getTopLeft(find.byType(TagChip).last).dy;
    final addTop = tester.getTopLeft(find.byType(AddTagChip)).dy;
    expect(firstTop, lastTop,
        reason: 'content-hugging chips stay in one row');
    expect(addTop, firstTop,
        reason: '"+ tag" chip stays in the same row as tag chips');
  });
}
