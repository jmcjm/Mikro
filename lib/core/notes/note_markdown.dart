/// A note as one Markdown document. The title is stored apart from the body (the generator splits
/// the leading `# heading` off), so it goes back on top as a level-1 heading; a note without a
/// title is just its body. Shared by everything that hands the whole note to the outside — the
/// translation request and the share action — so they cannot drift apart.
String noteMarkdown({required String title, required String content}) {
  final heading = title.trim();
  return heading.isEmpty ? content : '# $heading\n\n$content';
}
