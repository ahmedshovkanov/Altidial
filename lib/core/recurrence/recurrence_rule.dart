import 'package:altidial/core/time/day_time.dart';

/// How an event repeats. Persisted as [dbIndex] in
/// `event_series.recurrenceKind`; never reorder or reuse these numbers.
enum RecurrenceKind {
  none(0),
  daily(1),
  weekdays(2),
  custom(3);

  const RecurrenceKind(this.dbIndex);

  final int dbIndex;

  static RecurrenceKind fromDbIndex(int index) {
    for (final kind in RecurrenceKind.values) {
      if (kind.dbIndex == index) return kind;
    }
    throw ArgumentError.value(index, 'index', 'Unknown recurrence kind');
  }
}

/// The weekday mask bit for [weekday] (`DateTime.monday` … `DateTime.sunday`).
/// Monday is bit 0, as in the spec.
int _bitFor(int weekday) => 1 << (weekday - DateTime.monday);

const int _everyDayMask = 127;
const int _weekdaysMask = 31;

/// How an event repeats, and the last day it may occur on.
///
/// The first day is not part of the rule: it belongs to the series
/// (`event_series.validFrom`). [until] is the last day an occurrence may fall
/// on, as a local midnight, or null for a series that never ends.
class RecurrenceRule {
  const RecurrenceRule._(this.kind, this.weekdayMask, this.until);

  /// An event that does not repeat.
  const RecurrenceRule.none()
    : kind = RecurrenceKind.none,
      weekdayMask = 0,
      until = null;

  RecurrenceRule.daily({DateTime? until})
    : kind = RecurrenceKind.daily,
      weekdayMask = 0,
      until = until == null ? null : startOfDay(until);

  /// Monday to Friday.
  RecurrenceRule.weekdays({DateTime? until})
    : kind = RecurrenceKind.weekdays,
      weekdayMask = 0,
      until = until == null ? null : startOfDay(until);

  /// The given weekdays, as `DateTime.monday` … `DateTime.sunday`.
  RecurrenceRule.custom(Set<int> weekdays, {DateTime? until})
    : assert(weekdays.isNotEmpty, 'A custom rule needs at least one day'),
      kind = RecurrenceKind.custom,
      weekdayMask = weekdays.fold<int>(0, (mask, day) => mask | _bitFor(day)),
      until = until == null ? null : startOfDay(until);

  /// Rebuilds a rule from its stored columns. A custom rule with no days
  /// cannot occur on any day, so it reads back as [RecurrenceRule.none].
  factory RecurrenceRule.fromStored({
    required int kindIndex,
    required int weekdayMask,
    DateTime? until,
  }) {
    switch (RecurrenceKind.fromDbIndex(kindIndex)) {
      case RecurrenceKind.none:
        return const RecurrenceRule.none();
      case RecurrenceKind.daily:
        return RecurrenceRule.daily(until: until);
      case RecurrenceKind.weekdays:
        return RecurrenceRule.weekdays(until: until);
      case RecurrenceKind.custom:
        final mask = weekdayMask & _everyDayMask;
        if (mask == 0) return const RecurrenceRule.none();
        return RecurrenceRule._(
          RecurrenceKind.custom,
          mask,
          until == null ? null : startOfDay(until),
        );
    }
  }

  final RecurrenceKind kind;

  /// The stored mask. Only a custom rule has one; it is 0 for every other kind.
  final int weekdayMask;

  /// The last day an occurrence may fall on, or null.
  final DateTime? until;

  bool get repeats => kind != RecurrenceKind.none;

  /// The seven-bit mask of the days this rule occurs on, whatever its kind.
  int get effectiveMask => switch (kind) {
    RecurrenceKind.none => 0,
    RecurrenceKind.daily => _everyDayMask,
    RecurrenceKind.weekdays => _weekdaysMask,
    RecurrenceKind.custom => weekdayMask,
  };

  /// The weekdays this rule occurs on, as `DateTime.monday` … `DateTime.sunday`.
  Set<int> get weekdays => {
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      if (occursOnWeekday(day)) day,
  };

  bool occursOnWeekday(int weekday) => effectiveMask & _bitFor(weekday) != 0;

  RecurrenceRule withUntil(DateTime? until) => RecurrenceRule._(
    kind,
    weekdayMask,
    until == null ? null : startOfDay(until),
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.kind == kind &&
      other.weekdayMask == weekdayMask &&
      other.until == until;

  @override
  int get hashCode => Object.hash(kind, weekdayMask, until);

  @override
  String toString() => 'RecurrenceRule($kind, mask $weekdayMask, until $until)';
}

/// The days in [from, toExclusive) on which a series that follows [rule] and
/// starts on [validFrom] has an occurrence. Calendar arithmetic throughout, so
/// a daylight-saving change can never drop or repeat a day.
List<DateTime> occurrenceDates({
  required RecurrenceRule rule,
  required DateTime validFrom,
  required DateTime from,
  required DateTime toExclusive,
}) {
  if (!rule.repeats) return const [];
  final start = startOfDay(validFrom);
  final firstDay = startOfDay(from);
  final end = startOfDay(toExclusive);
  final last = rule.until;

  final dates = <DateTime>[];
  for (
    var day = firstDay.isBefore(start) ? start : firstDay;
    day.isBefore(end);
    day = nextDay(day)
  ) {
    if (last != null && day.isAfter(last)) break;
    if (rule.occursOnWeekday(day.weekday)) dates.add(day);
  }
  return dates;
}
