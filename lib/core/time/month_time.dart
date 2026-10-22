/// The first day of the month containing [day], at local midnight.
DateTime startOfMonth(DateTime day) => DateTime(day.year, day.month);

/// The first day of the month [delta] months after [month]'s month (before it,
/// if negative). Calendar arithmetic: the `DateTime` constructor carries a
/// month past 12 or before 1 into the year.
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// How many days [month]'s month has.
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// Whole months from [from]'s month to [to]'s month; negative when [to] is
/// earlier. Only the year and month count, never the day.
int monthsBetween(DateTime from, DateTime to) =>
    (to.year - from.year) * 12 + (to.month - from.month);

/// [month]'s month laid out as rows of seven cells, starting on [firstWeekday]
/// (`DateTime.monday` … `DateTime.sunday`, default Monday). A cell is that
/// day's local midnight, or null where the row runs outside the month.
List<List<DateTime?>> monthWeeks(
  DateTime month, {
  int firstWeekday = DateTime.monday,
}) {
  final first = startOfMonth(month);
  final leading = (first.weekday - firstWeekday + 7) % 7;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= daysInMonth(first); day++)
      DateTime(first.year, first.month, day),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [
    for (var start = 0; start < cells.length; start += 7)
      cells.sublist(start, start + 7),
  ];
}
