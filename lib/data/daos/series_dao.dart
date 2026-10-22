import 'package:drift/drift.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/event_series_table.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/sessions_table.dart';

part 'series_dao.g.dart';

/// Recurring series and the events they create (spec §4.2 and §4.3).
@DriftAccessor(tables: [EventSeries, Events, Sessions])
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.attachedDatabase);

  static final int _skipped = EventStatus.skipped.dbIndex;

  Future<int> insertSeries(EventSeriesCompanion entry) =>
      into(eventSeries).insert(entry);

  Future<EventSeriesRow?> seriesById(int id) => (select(
    eventSeries,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  /// The series that can have an occurrence somewhere in [from, toExclusive):
  /// started before the range ends, and not ended before it begins. Oldest
  /// first, so a crowded day always favours the older series.
  Future<List<EventSeriesRow>> seriesCovering(
    DateTime from,
    DateTime toExclusive,
  ) {
    return (select(eventSeries)
          ..where(
            (row) =>
                row.validFrom.isSmallerThanValue(toExclusive) &
                (row.validUntil.isNull() |
                    row.validUntil.isBiggerOrEqualValue(from)),
          )
          ..orderBy([(row) => OrderingTerm(expression: row.id)]))
        .get();
  }

  /// Ends the series after [validUntil] (that day is its last), or reopens it
  /// when [validUntil] is null.
  Future<void> setValidUntil(int id, DateTime? validUntil) {
    return (update(eventSeries)..where((row) => row.id.equals(id))).write(
      EventSeriesCompanion(validUntil: Value(validUntil)),
    );
  }

  Future<void> deleteSeries(int id) =>
      (delete(eventSeries)..where((row) => row.id.equals(id))).go();

  /// The (series, day) pair of every event a series has created in
  /// [from, toExclusive). Skipped rows are included on purpose: they are what
  /// stops a deleted occurrence being created again.
  Future<Set<({int seriesId, DateTime date})>> occurrenceKeys(
    DateTime from,
    DateTime toExclusive,
  ) async {
    final rows =
        await (select(events)..where(
              (row) =>
                  row.seriesId.isNotNull() &
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive),
            ))
            .get();
    return {for (final row in rows) (seriesId: row.seriesId!, date: row.date)};
  }

  /// Every event that is really on a day in [from, toExclusive), skipped rows
  /// left out. The materialiser checks ring room against these.
  Future<List<EventRow>> liveEventsBetween(
    DateTime from,
    DateTime toExclusive,
  ) {
    return (select(events)..where(
          (row) =>
              row.date.isBiggerOrEqualValue(from) &
              row.date.isSmallerThanValue(toExclusive) &
              row.status.isNotValue(_skipped),
        ))
        .get();
  }

  Future<EventRow?> eventById(int id) =>
      (select(events)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  /// Rewrites one event's fields and which series it belongs to; [seriesId]
  /// null detaches it into a one-off.
  Future<void> rewriteEvent({
    required int id,
    required String title,
    required int toneIndex,
    required int startMinute,
    required int endMinute,
    required int? seriesId,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        toneIndex: Value(toneIndex),
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
        seriesId: Value(seriesId),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Deletes every event the series has on [from] or later, skipped rows
  /// included, together with their sessions.
  Future<void> deleteOccurrencesFrom(int seriesId, DateTime from) async {
    final rows =
        await (select(events)..where(
              (row) =>
                  row.seriesId.equals(seriesId) &
                  row.date.isBiggerOrEqualValue(from),
            ))
            .get();
    if (rows.isEmpty) return;
    final ids = [for (final row in rows) row.id];
    await (delete(sessions)..where((row) => row.eventId.isIn(ids))).go();
    await (delete(events)..where((row) => row.id.isIn(ids))).go();
  }

  /// Deletes one event and its sessions, for good, whatever it belongs to.
  Future<void> deleteEventAndSessions(int id) async {
    await (delete(sessions)..where((row) => row.eventId.equals(id))).go();
    await (delete(events)..where((row) => row.id.equals(id))).go();
  }

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
