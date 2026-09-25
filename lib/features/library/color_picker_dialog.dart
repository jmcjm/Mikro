import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers.dart';
import '../../core/theme/accent_palette.dart';
import '../../l10n/app_localizations.dart';

/// Lets the user pick a colour for [tag]. The colour belongs to the tag, not to one recording
/// or note, so it changes everywhere the tag appears.
Future<void> showTagColorDialog(BuildContext context, WidgetRef ref, String tag) async {
  final picked = await _pick(context,
      title: AppLocalizations.of(context).tagColorTitle(tag),
      current: ref.read(tagColorsProvider).value?[tag]);
  if (picked == null) return;
  await ref.read(databaseProvider).setTagColor(tag, picked.index);
}

/// Lets the user pick a colour for a note.
Future<void> showNoteColorDialog(
    BuildContext context, WidgetRef ref, String noteId, int? current) async {
  final picked =
      await _pick(context, title: AppLocalizations.of(context).noteColorTitle, current: current);
  if (picked == null) return;
  await ref.read(databaseProvider).setNoteColor(noteId, picked.index);
}

Future<_Pick?> _pick(BuildContext context, {required String title, required int? current}) =>
    showDialog<_Pick>(
      context: context,
      builder: (context) => _ColorPickerDialog(title: title, current: current),
    );

/// Dialog result; wraps the index so "default" (null) differs from "dismissed".
class _Pick {
  const _Pick(this.index);
  final int? index;
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({required this.title, required this.current});

  final String title;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(int? index) {
      // Swatches show the colour itself: that is what a note's outline and dot use, and a tag
      // chip's tint is derived from it.
      final fill = AccentPalette.of(context).mark(index) ?? scheme.secondaryContainer;
      final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
          ? Colors.white
          : Colors.black;
      final selected = index == current;
      return Tooltip(
        message: index == null ? l10n.tagColorDefault : '',
        child: InkResponse(
          onTap: () => Navigator.pop(context, _Pick(index)),
          radius: 26,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(Symbols.check_rounded,
                    size: 22, color: index == null ? scheme.onSecondaryContainer : onFill)
                : null,
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(title),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          swatch(null),
          for (var i = 0; i < AccentPalette.count; i++) swatch(i),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.detailCancel)),
      ],
    );
  }
}
