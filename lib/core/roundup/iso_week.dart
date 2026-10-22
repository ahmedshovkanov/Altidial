/// ISO-8601 weeks: Monday–Sunday, week 1 containing the first Thursday, weeks
/// numbered against the year their Thursday falls in. Calendar arithmetic
/// throughout, so DST never shifts a week.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The ISO week [date] falls in. Verified edges: 2026-01-01 → (2026, 1),
/// 2025-12-29 → (2026, 1), 2026-12-31 → (2026, 53), 2026-10-07 → (2026, 41).
({int year, int week}) isoWeekOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final thursday = DateTime(
    day.year,
    day.month,
    day.day + (DateTime.thursday - day.weekday),
  );
  final jan4 = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return (year: thursday.year, week: _daysBetween(week1Monday, day) ~/ 7 + 1);
}

/// The Monday of ISO week [isoWeek] in [isoYear], at local midnight.
DateTime isoWeekStart(int isoYear, int isoWeek) {
  final jan4 = DateTime(isoYear, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return DateTime(
    week1Monday.year,
    week1Monday.month,
    week1Monday.day + (isoWeek - 1) * 7,
  );
}
