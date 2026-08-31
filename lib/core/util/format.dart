import 'package:intl/intl.dart';

String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String formatDateTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// Number for the playback speed pill ("1,0" in Polish, "1.0" in English). Decimal separator
/// comes from [locale] via intl, ensuring culturally correct formatting per language.
///
/// One decimal digit is the minimum so "1.0" does not collapse to "1" and cause the pill width
/// to jitter; two digits is the maximum required to display cycle steps like 1.25.
String formatPlaybackRate(double rate, {required String locale}) {
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 1
    ..maximumFractionDigits = 2;
  return format.format(rate);
}
