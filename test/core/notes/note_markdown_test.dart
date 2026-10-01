import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/notes/note_markdown.dart';

void main() {
  group('noteMarkdown', () {
    test('puts the title back on top of the body as a level-1 heading', () {
      expect(noteMarkdown(title: 'Plan', content: '- punkt'), '# Plan\n\n- punkt');
    });

    test('a note without a title is just its body', () {
      expect(noteMarkdown(title: '', content: 'Sama treść'), 'Sama treść');
    });

    test('a whitespace-only title counts as no title', () {
      expect(noteMarkdown(title: '  ', content: 'Sama treść'), 'Sama treść');
    });

    test('spaces around the title do not reach the heading', () {
      expect(noteMarkdown(title: ' Plan ', content: 'x'), '# Plan\n\nx');
    });
  });
}
