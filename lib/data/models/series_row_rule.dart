import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/data/database.dart';

/// Reads a stored series back as the rule it follows. The series' last day
/// (`validUntil`) is the rule's end day.
extension EventSeriesRowRule on EventSeriesRow {
  RecurrenceRule get rule => RecurrenceRule.fromStored(
    kindIndex: recurrenceKind,
    weekdayMask: weekdayMask,
    until: validUntil,
  );
}
