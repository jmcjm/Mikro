import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/provider_config.dart';
import '../../core/notes/note_style.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// Picker label of a user's style; the one migrated from older versions has no name.
String customNoteStyleName(CustomNoteStyle style, AppLocalizations l10n) =>
    style.name.trim().isEmpty ? l10n.noteStyleCustom : style.name;

/// Asks which style to write a note in, right before generating it. [message] is shown above
/// the styles (the regenerate warning), [confirmLabel] names the action. The last used style
/// is preselected and the confirmed one is remembered for next time. `null` means cancelled.
Future<NoteStyleChoice?> pickNoteStyle(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? message,
  required String confirmLabel,
}) async {
  // Read before the await: the caller may be gone by the time the dialog closes.
  final prefs = ref.read(sharedPrefsProvider);
  final choice = await showDialog<NoteStyleChoice>(
    context: context,
    builder: (_) => _NoteStyleDialog(title: title, message: message, confirmLabel: confirmLabel),
  );
  if (choice != null) await saveLastNoteStyle(prefs, choice);
  return choice;
}

class _NoteStyleDialog extends ConsumerStatefulWidget {
  const _NoteStyleDialog({required this.title, this.message, required this.confirmLabel});

  final String title;
  final String? message;
  final String confirmLabel;

  @override
  ConsumerState<_NoteStyleDialog> createState() => _NoteStyleDialogState();
}

class _NoteStyleDialogState extends ConsumerState<_NoteStyleDialog> {
  late NoteStyleChoice _selected =
      lastNoteStyle(ref.read(sharedPrefsProvider), ref.read(customNoteStylesProvider));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final custom = ref.watch(customNoteStylesProvider);
    final options = <(NoteStyleChoice, String, String)>[
      (const NoteStyleChoice.preset(NoteStyle.detailed), l10n.noteStyleDetailed,
          l10n.noteStyleDetailedHelp),
      (const NoteStyleChoice.preset(NoteStyle.concise), l10n.noteStyleConcise,
          l10n.noteStyleConciseHelp),
      (const NoteStyleChoice.preset(NoteStyle.meeting), l10n.noteStyleMeeting,
          l10n.noteStyleMeetingHelp),
      (const NoteStyleChoice.preset(NoteStyle.casual), l10n.noteStyleCasual,
          l10n.noteStyleCasualHelp),
      for (final style in custom)
        (NoteStyleChoice.custom(style), customNoteStyleName(style, l10n), style.instructions),
    ];
    // The preselected style may have been deleted in the meantime.
    final selected = options.where((o) => o.$1 == _selected).firstOrNull ?? options.first;
    final helpStyle = TextStyle(fontSize: 13, color: colors.onSurfaceVariant);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.message case final message?) ...[
                Text(message),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (choice, label, _) in options)
                    ChoiceChip(
                      label: Text(label),
                      selected: choice == selected.$1,
                      onSelected: (_) => setState(() => _selected = choice),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(selected.$3,
                    maxLines: 4, overflow: TextOverflow.ellipsis, style: helpStyle),
              ),
              if (custom.isEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l10n.noteStyleCustomHint,
                      style: helpStyle.copyWith(fontStyle: FontStyle.italic)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.detailCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected.$1),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
