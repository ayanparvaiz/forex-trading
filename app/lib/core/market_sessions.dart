/// The four centres the forex day moves through, and when their desks are
/// open.
///
/// Hours are each city's own, so daylight saving moves a session the way it
/// moves the people working it. No time-zone database: the four rules are
/// written out below, which is all this needs.
enum MarketSession {
  sydney(openHour: 7, closeHour: 16),
  tokyo(openHour: 9, closeHour: 18),
  london(openHour: 8, closeHour: 17),
  newYork(openHour: 8, closeHour: 17);

  const MarketSession({required this.openHour, required this.closeHour});

  /// Local hours, on weekdays: open from [openHour] until [closeHour].
  final int openHour;
  final int closeHour;

  /// Hours ahead of UTC at the instant [utc].
  int utcOffset(DateTime utc) => switch (this) {
    sydney => _sydneySummer(utc) ? 11 : 10,
    tokyo => 9,
    london => _londonSummer(utc) ? 1 : 0,
    newYork => _newYorkSummer(utc) ? -4 : -5,
  };

  /// Whether its desks are open at [utc]: a weekday there, within hours.
  bool isOpenAt(DateTime utc) {
    final local = utc.toUtc().add(Duration(hours: utcOffset(utc.toUtc())));
    if (local.weekday == DateTime.saturday ||
        local.weekday == DateTime.sunday) {
      return false;
    }
    return local.hour >= openHour && local.hour < closeHour;
  }

  /// How long until it next opens, when closed, or closes, when open.
  ///
  /// Every change happens on a whole hour — the openings, and the clocks
  /// going forward or back — so the next whole hours are all there is to
  /// look at. A week of them covers the longest wait, over a weekend.
  Duration changeIn(DateTime utc) {
    final now = utc.toUtc();
    final open = isOpenAt(now);
    var hour = DateTime.utc(now.year, now.month, now.day, now.hour + 1);
    for (var i = 0; i < 24 * 8; i++) {
      if (isOpenAt(hour) != open) return hour.difference(now);
      hour = hour.add(const Duration(hours: 1));
    }
    return Duration.zero;
  }
}

/// Whether London and New York are both open: the busiest hours of the day.
bool busiestHours(DateTime utc) =>
    MarketSession.london.isOpenAt(utc) && MarketSession.newYork.isOpenAt(utc);

/// The forex weekend: from New York's Friday close to Sydney's Monday open.
bool marketWeekend(DateTime utc) =>
    !MarketSession.values.any((s) => s.isOpenAt(utc)) &&
    _weekendDay(utc.toUtc());

bool _weekendDay(DateTime utc) {
  final ny = utc.add(Duration(hours: MarketSession.newYork.utcOffset(utc)));
  return ny.weekday == DateTime.saturday ||
      (ny.weekday == DateTime.friday && ny.hour >= 17) ||
      (ny.weekday == DateTime.sunday && ny.hour < 17);
}

/// Day [n] of the weekday [weekday] in a month, counted from its start; the
/// last one when [n] is -1.
DateTime _nth(int year, int month, int weekday, int n) {
  if (n == -1) {
    final last = DateTime.utc(year, month + 1, 0);
    return last.subtract(Duration(days: (last.weekday - weekday) % 7));
  }
  final first = DateTime.utc(year, month);
  return first.add(Duration(days: (weekday - first.weekday) % 7 + 7 * (n - 1)));
}

/// UK summer time: from 01:00 UTC on March's last Sunday to 01:00 UTC on
/// October's.
bool _londonSummer(DateTime utc) {
  final start = _nth(utc.year, 3, DateTime.sunday, -1).add(_hours(1));
  final end = _nth(utc.year, 10, DateTime.sunday, -1).add(_hours(1));
  return !utc.isBefore(start) && utc.isBefore(end);
}

/// US daylight time: from 02:00 local (07:00 UTC) on March's second Sunday
/// to 02:00 local (06:00 UTC) on November's first.
bool _newYorkSummer(DateTime utc) {
  final start = _nth(utc.year, 3, DateTime.sunday, 2).add(_hours(7));
  final end = _nth(utc.year, 11, DateTime.sunday, 1).add(_hours(6));
  return !utc.isBefore(start) && utc.isBefore(end);
}

/// Sydney's summer runs across the new year: from 02:00 local on October's
/// first Sunday to 03:00 local on April's — 16:00 UTC the Saturday before,
/// both times.
bool _sydneySummer(DateTime utc) {
  final ends = _nth(utc.year, 4, DateTime.sunday, 1).subtract(_hours(8));
  final starts = _nth(utc.year, 10, DateTime.sunday, 1).subtract(_hours(8));
  return utc.isBefore(ends) || !utc.isBefore(starts);
}

Duration _hours(int h) => Duration(hours: h);
