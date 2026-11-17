import 'package:intl/intl.dart';

/// 1.7321 → "1.73"
String fmtGrade(double? g) => g == null ? '—' : g.toStringAsFixed(2);

/// 87.2 → "87.20%"; [dp] decimals.
String fmtPct(double? p, {int dp = 2, bool sign = false}) {
  if (p == null) return '—';
  return '${p.toStringAsFixed(dp)}%';
}

/// 3.0 → "3", 2.5 → "2.5", 44.5 → "44.5"
String fmtNum(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String fmtUnits(double u) => '${fmtNum(u)} ${u == 1 ? 'unit' : 'units'}';

final _md = DateFormat('MMM d');
final _wmd = DateFormat('EEE, MMM d');
final _mdy = DateFormat('MMM d, yyyy');
final _day = DateFormat('EEE');

String fmtMd(DateTime d) => _md.format(d); // Nov 18
String fmtWmd(DateTime d) => _wmd.format(d); // Wed, Nov 18
String fmtMdy(DateTime d) => _mdy.format(d); // Nov 10, 2026
String fmtDay(DateTime d) => _day.format(d);

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Tomorrow", "In 3 days", "2 days ago", "Wed, Nov 18".
String fmtRelative(DateTime date, DateTime now) {
  final diff = dayOf(date).difference(dayOf(now)).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    > 1 && < 7 => 'In $diff days',
    < -1 && > -7 => '${-diff} days ago',
    _ => fmtWmd(date),
  };
}
