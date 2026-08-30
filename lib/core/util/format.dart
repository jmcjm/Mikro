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

/// Liczba w pigulce predkosci ("1,0" po polsku, "1.0" po angielsku). Separator dziesietny idzie
/// z [locale] przez intl, bo w polskim ekranie kropka byla by kalka.
///
/// Jedna cyfra po separatorze to minimum, zeby "1,0" nie schudlo do "1" i pigulka nie skakala
/// na szerokosci; dwie to maksimum, ktore mieszcza kroki cyklu (1,25).
String formatPlaybackRate(double rate, {required String locale}) {
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 1
    ..maximumFractionDigits = 2;
  return format.format(rate);
}
