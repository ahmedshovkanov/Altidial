/// Minutes in one day. One full rotation of the dial.
const int minutesPerDay = 1440;

/// Shortest event the dial allows.
const int minEventMinutes = 15;

/// Drag snapping granularity.
const int snapStepMinutes = 5;

/// Local midnight of [dateTime]'s calendar date.
DateTime startOfDay(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// The local midnight one calendar day after [day].
///
/// Calendar arithmetic, not `Duration(days: 1)`: adding 24 real hours to a
/// 25-hour DST fall-back day lands back on the same date, which would make
/// "next day" a silent no-op once a year. The `DateTime` constructor
/// normalises out-of-range components, so month and year rollover work too.
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

/// The local midnight one calendar day before [day]. See [nextDay].
DateTime previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

/// Minutes elapsed since local midnight, 0–1439.
int minuteOfDay(DateTime dateTime) => dateTime.hour * 60 + dateTime.minute;

/// Formats a minute-of-day as `HH:mm`. The exclusive end-of-day value 1440
/// renders as `24:00` rather than wrapping to `00:00`.
String formatMinuteOfDay(int minute) {
  final hour = minute ~/ 60;
  final minutes = minute % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

String formatMinuteRange(int startMinute, int endMinute) =>
    '${formatMinuteOfDay(startMinute)} – ${formatMinuteOfDay(endMinute)}';

String formatDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

/// True when [day] falls strictly before today. Past days are read-only.
bool isPastDay(DateTime day, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  return startOfDay(day).isBefore(today);
}

/// A duration spoken in full words, for screen readers: "1 hour 30 minutes".
String spokenDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final hourText = hours == 1 ? '1 hour' : '$hours hours';
  final minuteText = remainder == 1 ? '1 minute' : '$remainder minutes';
  if (hours == 0) return minuteText;
  if (remainder == 0) return hourText;
  return '$hourText $minuteText';
}

/// The [firstWeekday] on or before [day], at local midnight. [firstWeekday] is
/// `DateTime.monday` … `DateTime.sunday` and defaults to Monday, so callers
/// that have not heard of the setting keep their week. Calendar arithmetic, so
/// a DST change inside the week cannot move the result by a day.
DateTime startOfWeek(DateTime day, {int firstWeekday = DateTime.monday}) {
  final midnight = startOfDay(day);
  final shift = (midnight.weekday - firstWeekday + 7) % 7;
  return DateTime(midnight.year, midnight.month, midnight.day - shift);
}

/// The seven local midnights of the week containing [day], starting on
/// [firstWeekday].
List<DateTime> daysOfWeek(DateTime day, {int firstWeekday = DateTime.monday}) {
  final first = startOfWeek(day, firstWeekday: firstWeekday);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}

/// A countdown for the session ring: "04:05", or "1:02:03" from one hour up.
/// Negative values show as zero.
String formatCountdown(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final secs = (total % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$secs' : '$hours:$minutes:$secs';
}

/// How long until the next minute boundary, so clocks tick exactly on it.
Duration untilNextMinute(DateTime now) {
  final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
  return next.difference(now);
}

/// Seconds spoken in words for screen readers: "1 hour 5 minutes 3 seconds".
/// Parts that are zero are left out.
String spokenDurationSeconds(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final parts = [
    if (hours > 0) hours == 1 ? '1 hour' : '$hours hours',
    if (minutes > 0) minutes == 1 ? '1 minute' : '$minutes minutes',
    if (secs > 0 || total == 0) secs == 1 ? '1 second' : '$secs seconds',
  ];
  return parts.join(' ');
}
