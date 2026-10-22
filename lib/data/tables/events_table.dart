import 'package:drift/drift.dart';

/// Concrete event occurrences. One row per event per date. Recurring series
/// are materialised into rows here, so nothing downstream contains
/// recurrence logic.
@TableIndex(name: 'events_date', columns: {#date})
@TableIndex(name: 'events_series_date', columns: {#seriesId, #date})
@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Null for one-off events; set when materialised from an [EventSeries].
  IntColumn get seriesId => integer().nullable()();

  /// Local midnight of the day this event belongs to.
  DateTimeColumn get date => dateTime()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get toneIndex => integer()();

  /// 0–1439.
  IntColumn get startMinute => integer()();

  /// 1–1440, exclusive. Never crosses midnight.
  IntColumn get endMinute => integer()();

  /// 0 planned, 1 completed, 2 skipped.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// True when this event is a manually-entered flight block (spec: travel
  /// day mode v1). Tone is forced to Inbox; rendering branches on this flag.
  BoolColumn get isFlight => boolean().withDefault(const Constant(false))();

  /// Optional, uppercased, e.g. LH715. Null when empty or not a flight.
  TextColumn get flightNumber => text().nullable()();

  /// IATA codes, uppercased, e.g. SOF. Null unless [isFlight].
  TextColumn get fromCode => text().nullable()();
  TextColumn get toCode => text().nullable()();

  /// Nullable link to a project. Null = no project. Follows the seriesId precedent.
  IntColumn get projectId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
