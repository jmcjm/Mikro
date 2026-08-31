import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/models/recording_status.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Shared visual elements for library and recording details, matching design mockups
/// (`design/Mikro-MD3.dc.html`, "Library" and "Details" sections). Both screens render identical
/// status badges and tag chips.

/// Technical caption (date, model name) in monospace font per design. Font family is resolved
/// from [monoFontFamily] constant matching the bundled asset.
TextStyle monoStyle({required double size, required Color color}) => TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFallback,
      fontSize: size,
      color: color,
    );

/// Fixed-width numbers for text values updating in place (playback timestamps, duration).
/// Matches `font-variant-numeric:tabular-nums` from mockup to prevent jitter during updates.
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

/// Status badge label. Displayed in title case matching the restyled badge design.
String statusLabel(RecordingStatus status, AppLocalizations l10n) => switch (status) {
      RecordingStatus.recorded => l10n.statusQueued,
      RecordingStatus.transcribing => l10n.statusTranscribing,
      RecordingStatus.tagging => l10n.statusTagging,
      RecordingStatus.done => l10n.statusDone,
      RecordingStatus.error => l10n.statusError,
    };

/// Whether a recording is currently in progress — determines progress indicator visibility on the card.
bool isInProgress(RecordingStatus status) =>
    status == RecordingStatus.recorded ||
    status == RecordingStatus.transcribing ||
    status == RecordingStatus.tagging;

/// Status badge: height 24, radius 8, icon 14, label 12/w700 — per mockup.
///
/// Role-based color tokens: done uses `surfaceContainerHigh`, in-progress uses
/// `primaryContainer`, error uses `error`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.showIcon = true});

  final RecordingStatus status;

  /// Library list cards include the badge icon, whereas the detail header shows only the label.
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

/// Tag chip used on library card (`dense`) and in detail views (full size).
///
/// [onDelete] adds a trailing delete icon to remove the tag from the recording.
/// Only detail views receive deletion capability; on library cards and filter bars tags act as filters.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.dense = false,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final bool dense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: dense ? 26 : 32,
          padding: EdgeInsets.only(
            left: dense ? 10 : 12,
            // The delete icon carries its own padding, so the chip needs less right padding when present.
            right: onDelete != null ? 4 : (dense ? 10 : 12),
          ),
          // Center with widthFactor 1 centers content vertically while sizing horizontally to the child.
          // Container.alignment would stretch the chip full width inside bounded constraints.
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: dense ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                if (onDelete != null)
                  Tooltip(
                    message: l10n.detailRemoveTagTooltip,
                    // The close icon itself is the tap target, preventing accidental deletions when tapping the label.
                    child: InkResponse(
                      onTap: onDelete,
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Icon(Symbols.close_rounded,
                            fill: 1, size: 16, color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ tag" action chip in detail tag list: shares geometry with [TagChip] (height 32,
/// radius 8, horizontal padding 12), rendered with a dashed border in `outline` color.
class AddTagChip extends StatelessWidget {
  const AddTagChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: scheme.outline),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // Center with widthFactor 1 instead of Container.alignment — see [TagChip] note.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.add_rounded,
                      fill: 1, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    l10n.detailAddTagChip,
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed border painter with corner radius 8 — `border: 1px dashed` from mockup.
/// Extracted via [Path.computeMetrics].
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Half-pixel deflation keeps 1 px stroke fully within tile bounds.
    final outline = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8))
        .deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in (Path()..addRRect(outline)).computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + _dash, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

/// Action button for error banner: height 32, radius 16, filled with `error` role.
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
