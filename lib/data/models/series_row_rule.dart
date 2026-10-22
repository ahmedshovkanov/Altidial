import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/data/database.dart';

/// Reads a stored series back as the rule it follows. The series' last day
/// (`validUntil`) is the rule's end day.
extension EventSeriesRowRule on EventSeriesRow {
  RecurrenceRule get rule => RecurrenceRule.fromStored(
    kindIndex: recurrenceKind,
    weekdayMask: weekdayMask,
    until: validUntil,
  );
}
