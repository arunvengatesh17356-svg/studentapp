import 'package:flutter/material.dart';

/// The PHP API sometimes returns numbers as strings ("5000.00", "3"),
/// so always read values through these helpers.
int toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? fallback;
}

double toDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? fallback;
}

String str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

List<Map<String, dynamic>> asList(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-10-07" or "2026-10-07 11:28:00"  ->  "7 Oct 2026"
String formatDate(dynamic v) {
  final s = str(v);
  if (s.isEmpty) return '—';
  final d = DateTime.tryParse(s.length > 10 ? s.replaceFirst(' ', 'T') : s);
  if (d == null) return s;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "2026-10-07 15:05:00" -> "7 Oct 2026, 3:05 PM"
String formatDateTime(dynamic v) {
  final s = str(v);
  if (s.isEmpty) return '—';
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (d == null) return s;
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h12:${d.minute.toString().padLeft(2, '0')} $ampm';
}

/// DateTime -> "2026-10-07 15:05:00" (the format the exam API expects)
String sqlDateTime(DateTime d) =>
    '${ymd(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

DateTime? parseSqlDateTime(dynamic v) {
  final s = str(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

/// 3725 -> "1:02:05", 125 -> "2:05"
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// Marks like 4.0 -> "4", 2.5 -> "2.5"
String formatMarks(dynamic v) {
  final n = toDouble(v);
  return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
}

/// DateTime -> "2026-10-07" (the format the API expects)
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _groupIndian(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final b = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) b.write(',');
    b.write(rest[i]);
  }
  return '$b,$last3';
}

String formatPrice(dynamic v) {
  final n = toDouble(v);
  if (n <= 0) return 'Free';
  final whole = n.truncate();
  final paise = ((n - whole) * 100).round();
  if (paise == 0) return '₹${_groupIndian(whole)}';
  return '₹${_groupIndian(whole)}.${paise.toString().padLeft(2, '0')}';
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

MaterialColor statusSwatch(String status) {
  switch (status.toLowerCase()) {
    case 'present':
    case 'approved':
    case 'paid':
    case 'published':
    case 'active':
    case 'completed':
    case 'purchased':
      return Colors.green;
    case 'late':
    case 'pending':
    case 'on leave':
    case 'started':
    case 'graded':
      return Colors.orange;
    case 'submitted':
    case 'quiz':
    case 'paper':
      return Colors.blue;
    case 'absent':
    case 'rejected':
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
