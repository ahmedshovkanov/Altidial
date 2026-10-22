import 'package:drift/drift.dart';

/// Recurrence rules. Written in Phase 3; the table exists from schema v1 so
/// that adding recurrence later needs no migration.
@DataClassName('EventSeriesRow')
class EventSeries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get toneIndex => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();

  /// 0 none, 1 daily, 2 weekdays, 3 custom mask.
  IntColumn get recurrenceKind => integer()();

  /// Seven-bit mask, Monday is bit 0.
  IntColumn get weekdayMask => integer().withDefault(const Constant(0))();

  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
