import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/db/database.dart';
import '../../core/models/translation_language.dart';
import '../../l10n/app_localizations.dart';

/// Asks for a target language; [last] (the one used last time) is listed first. Returns the
/// language code, or `null` when dismissed.
Future<String?> pickTranslationLanguage(BuildContext context, {String? last}) {
  final languages = [
    if (last != null) TranslationLanguage.of(last),
    ...TranslationLanguage.all.where((l) => l.code != last),
  ];
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(AppLocalizations.of(context).translatePickTitle),
      children: [
        SizedBox(
          width: 320,
          height: 420,
          child: ListView(
            children: [
              for (final language in languages)
                ListTile(
                  leading: language.code == last
                      ? const Icon(Symbols.history_rounded, fill: 1)
                      : const SizedBox(width: 24),
                  title: Text(language.nativeName),
                  onTap: () => Navigator.pop(context, language.code),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// "Original | English | Deutsch …" row above a transcript or note. [selected] is a language
/// code, `null` for the original. Hidden entirely when there are no translations.
class TranslationSwitcher extends StatelessWidget {
  const TranslationSwitcher({
    super.key,
    required this.translations,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final List<Translation> translations;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<Translation> onDelete;

  @override
  Widget build(BuildContext context) {
    if (translations.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(l10n.translationOriginal),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
            for (final t in translations) ...[
              const SizedBox(width: 8),
              InputChip(
                avatar: const Icon(Symbols.translate_rounded, size: 16),
                label: Text(TranslationLanguage.of(t.language).nativeName),
                selected: selected == t.language,
                onSelected: (_) => onSelect(t.language),
                onDeleted: () => onDelete(t),
                deleteButtonTooltipMessage: l10n.translationDeleteTooltip,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Translation button: spinner while [busy]. [compact] matches the small icon buttons in the
/// transcript card header; otherwise it is a regular app-bar sized button.
class TranslateButton extends StatelessWidget {
  const TranslateButton({
    super.key,
    required this.busy,
    required this.onPressed,
    this.color,
    this.compact = false,
  });

  final bool busy;
  final VoidCallback onPressed;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 20.0 : 24.0;
    if (busy) {
      return Padding(
        padding: EdgeInsets.all(compact ? 0 : 12),
        child: SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: Icon(Symbols.translate_rounded, fill: 1, size: size, color: color),
      tooltip: AppLocalizations.of(context).translateTooltip,
      onPressed: onPressed,
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? EdgeInsets.zero : null,
      constraints: compact ? const BoxConstraints() : null,
    );
  }
}
