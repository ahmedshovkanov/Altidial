import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:intl/intl.dart';

/// How a rule reads to a person: "Every day", "Weekdays",
/// "Every Mon, Wed and Fri", each followed by ", until 31 Dec 2026" when the
/// series ends.
String describeRecurrence(RecurrenceRule rule) {
  if (!rule.repeats) return Strings.repeatNone;

  final mask = rule.effectiveMask;
  final base = switch (mask) {
    127 => Strings.repeatDaily,
    31 => Strings.repeatWeekdays,
    _ => Strings.repeatEvery(
      Strings.joinWords([
        for (final weekday in rule.weekdays)
          Strings.weekdayShort[weekday - DateTime.monday],
      ]),
    ),
  };

  final until = rule.until;
  if (until == null) return base;
  return '$base, ${Strings.repeatUntil(DateFormat('d MMM y').format(until))}';
}
