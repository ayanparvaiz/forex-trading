import '../models/trade.dart';

/// How a day went, by the rules: every trade closed that day kept them, some
/// did, or none did.
enum DayMark { clean, mixed, broken }

/// Each day trades were closed on, marked. Days are local midnights.
Map<DateTime, DayMark> dayMarks(Iterable<Trade> trades) {
  final kept = <DateTime, int>{};
  final total = <DateTime, int>{};
  for (final t in trades) {
    final closed = t.closedAt;
    if (closed == null) continue;
    final l = closed.toLocal();
    final day = DateTime(l.year, l.month, l.day);
    total[day] = (total[day] ?? 0) + 1;
    if (t.violations.isEmpty) kept[day] = (kept[day] ?? 0) + 1;
  }
  return {
    for (final MapEntry(key: day, value: n) in total.entries)
      day: switch (kept[day] ?? 0) {
        final k when k == n => DayMark.clean,
        0 => DayMark.broken,
        _ => DayMark.mixed,
      },
  };
}

/// The Mondays starting the last [weeks] weeks, oldest first — the
/// calendar's columns — ending with the week [today] is in.
List<DateTime> weekStarts(DateTime today, int weeks) {
  final d = DateTime(today.year, today.month, today.day);
  final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
  return [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(monday.year, monday.month, monday.day - 7 * i),
  ];
}

/// Clean days in a row, back from [today] — today counting only once it has
/// a trade, so a morning without one does not break yesterday's run.
int cleanStreak(Map<DateTime, DayMark> marks, DateTime today) {
  var day = DateTime(today.year, today.month, today.day);
  if (!marks.containsKey(day)) day = DateTime(day.year, day.month, day.day - 1);
  var n = 0;
  // Days without trades neither break a run nor add to it.
  for (var gap = 0; gap < 400; gap++) {
    final mark = marks[day];
    if (mark == DayMark.clean) n++;
    if (mark == DayMark.mixed || mark == DayMark.broken) break;
    day = DateTime(day.year, day.month, day.day - 1);
    if (!marks.keys.any((d) => !d.isAfter(day))) break;
  }
  return n;
}
