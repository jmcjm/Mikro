import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/recording_status.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Wspolne elementy wizualne biblioteki i szczegolow nagrania, przepisane 1:1 z makiet
/// (`design/Mikro-MD3.dc.html`, sekcje "Biblioteka" i "Szczegoly"). Oba ekrany rysuja te same
/// odznaki statusu i chipy tagow, wiec mieszkaja tutaj zamiast byc kopiowane.

/// Podpis techniczny (data, nazwa modelu) krojem monospace — tak sklada je design. Rodzina idzie
/// ze stalej [monoFontFamily], bo font jest bundlowany pod ta jedna nazwa.
TextStyle monoStyle({required double size, required Color color}) => TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFallback,
      fontSize: size,
      color: color,
    );

/// Liczby, ktore zmieniaja sie w miejscu (czasy odtwarzania, dlugosc nagrania). Cyfry o stalej
/// szerokosci, zgodnie z `font-variant-numeric:tabular-nums` z makiety — bez tego licznik
/// pozycji skacze przy kazdej zmianie cyfry.
TextStyle tabularStyle({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Etykieta statusu w odznace. Makieta pisze je wielka litera ("Tagowanie…", "Gotowe",
/// "Blad"), bo w restylowanym ukladzie status jest odznaka, a nie zdaniem w tresci karty.
String statusLabel(RecordingStatus status, AppLocalizations l10n) => switch (status) {
      RecordingStatus.recorded => l10n.statusQueued,
      RecordingStatus.transcribing => l10n.statusTranscribing,
      RecordingStatus.tagging => l10n.statusTagging,
      RecordingStatus.done => l10n.statusDone,
      RecordingStatus.error => l10n.statusError,
    };

/// Czy nagranie jest w trakcie przetwarzania — decyduje o pasku postepu na karcie.
bool isInProgress(RecordingStatus status) =>
    status == RecordingStatus.recorded ||
    status == RecordingStatus.transcribing ||
    status == RecordingStatus.tagging;

/// Odznaka statusu: wysokosc 24, promien 8, ikona 14 i etykieta 12/w700 — jak w makiecie.
///
/// Kolory bierze z rol schematu: gotowe siedzi na `surfaceContainerHigh`, przetwarzanie na
/// `primaryContainer`, blad na pelnym `error`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.showIcon = true});

  final RecordingStatus status;

  /// Karta w bibliotece ma ikone w odznace, naglowek szczegolow — sama etykiete.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final (background, foreground, icon) = switch (status) {
      RecordingStatus.error => (scheme.error, scheme.onError, Symbols.error_rounded),
      RecordingStatus.done => (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          Symbols.check_circle_rounded,
        ),
      _ => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Symbols.auto_awesome_rounded,
        ),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, fill: 1, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            statusLabel(status, l10n),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip tagu na karcie (`dense`) i w szczegolach (pelny rozmiar).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.dense = false, this.onTap});

  final String label;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: dense ? 26 : 32,
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: dense ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Przycisk akcji na tle bledu: wysokosc 32, promien 16, wypelnienie rola `error`.
class ErrorActionButton extends StatelessWidget {
  const ErrorActionButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label),
    );
  }
}
