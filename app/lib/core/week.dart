/// The ISO week [now] falls in, in Dhaka time — Monday to Sunday — named
/// like "2026-W40". The worker names weeks the same way
/// (worker/src/weekly.js), so asking for this week's board asks for the
/// week the worker wrote.
String weekId(DateTime now) {
  // The Dhaka calendar day: UTC+6, no daylight saving.
  final dhaka = now.toUtc().add(const Duration(hours: 6));
  final day = DateTime.utc(dhaka.year, dhaka.month, dhaka.day);
  // The Thursday of this week decides which year the week belongs to.
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final jan1 = DateTime.utc(thursday.year);
  final week = thursday.difference(jan1).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}
