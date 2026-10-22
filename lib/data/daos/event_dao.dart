import 'package:drift/drift.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/sessions_table.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events, Sessions])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.attachedDatabase);

  /// `events.status == 2` is a deleted occurrence of a series. It stays in the
  /// table so the series cannot bring it back, but it is nothing on the screen
  /// and subtracts nothing from any total.
  static const _skipped = 2;

  /// The day's events, oldest first, without the skipped rows.
  SimpleSelectStatement<$EventsTable, EventRow> _dayQuery(DateTime day) =>
      select(events)
        ..where((row) => row.date.equals(day) & row.status.isNotValue(_skipped))
        ..orderBy([
          (row) => OrderingTerm(expression: row.startMinute),
          (row) => OrderingTerm(expression: row.id),
        ]);

  Stream<List<EventRow>> watchDay(DateTime day) => _dayQuery(day).watch();

  Future<List<EventRow>> eventsForDay(DateTime day) => _dayQuery(day).get();

  /// Every non-deleted event in `[from, toExclusive)`, oldest first. Feeds the
  /// notification scheduler's 7-day horizon.
  Future<List<EventRow>> eventsBetween(DateTime from, DateTime toExclusive) =>
      (select(events)
            ..where(
              (row) =>
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .get();

  /// Every non-deleted event in `[from, toExclusive)`, oldest first, as a
  /// stream. Feeds range readers such as the Flight Deck.
  Stream<List<EventRow>> watchRange(DateTime from, DateTime toExclusive) =>
      (select(events)
            ..where(
              (row) =>
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .watch();

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  Future<void> updateTimes({
    required int id,
    required int startMinute,
    required int endMinute,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> updateDetails({
    required int id,
    required String title,
    required int toneIndex,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        toneIndex: Value(toneIndex),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Deletes the event and every session timed on it. A one-off event leaves
  /// the table; an occurrence that belongs to a series stays as a `skipped`
  /// (status 2) row under the same id, so the materialiser will not bring it
  /// back.
  Future<void> deleteById(int id, {required DateTime now}) {
    return transaction(() async {
      final row = await (select(
        events,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      await (delete(sessions)..where((row) => row.eventId.equals(id))).go();
      if (row == null) return;
      if (row.seriesId != null) {
        await (update(events)..where((row) => row.id.equals(id))).write(
          EventsCompanion(status: const Value(_skipped), updatedAt: Value(now)),
        );
        return;
      }
      await (delete(events)..where((row) => row.id.equals(id))).go();
    });
  }

  /// Distinct (date, tone) pairs for dates in [from, toExclusive). Feeds the
  /// week strip's dots without loading any events.
  Stream<List<({DateTime date, int toneIndex})>> watchToneDays(
    DateTime from,
    DateTime toExclusive,
  ) {
    final query = selectOnly(events, distinct: true)
      ..addColumns([events.date, events.toneIndex])
      ..where(
        events.date.isBiggerOrEqualValue(from) &
            events.date.isSmallerThanValue(toExclusive) &
            events.status.isNotValue(_skipped),
      );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
          ),
      ],
    );
  }

  /// Planned minutes per tone for each date in [from, toExclusive): one row for
  /// every (date, tone) that has events. Feeds the Calendar's month rings with
  /// one grouped query. Overlapping events count twice, because overlap is
  /// extra load.
  Stream<List<({DateTime date, int toneIndex, int minutes})>> watchToneMinutes(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query = selectOnly(events)
      ..addColumns([events.date, events.toneIndex, minutes])
      ..where(
        events.date.isBiggerOrEqualValue(from) &
            events.date.isSmallerThanValue(toExclusive) &
            events.status.isNotValue(_skipped),
      )
      ..groupBy([events.date, events.toneIndex]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
            minutes: row.read(minutes) ?? 0,
          ),
      ],
    );
  }
  /// Replaces the flight flag and flight columns of one event. Clearing means
  /// `isFlight: false` with all three columns null (callers enforce this).
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        isFlight: Value(isFlight),
        flightNumber: Value(flightNumber),
        fromCode: Value(fromCode),
        toCode: Value(toCode),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Links ([projectId]) or unlinks (null) one event to a project.
  Future<void> updateProject({required int id, required int? projectId}) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(projectId: Value(projectId)),
    );
  }

  /// Links/unlinks every non-skipped event of [seriesId] on or after
  /// [fromDate] (dates are stored at day granularity). Used by the
  /// edit-all-future path; the single-row [updateProject] stays for this-event.
  Future<void> updateProjectForSeries({
    required int seriesId,
    required DateTime fromDate,
    required int? projectId,
  }) {
    return (update(events)..where(
            (row) =>
                row.seriesId.equals(seriesId) &
                row.date.isBiggerOrEqualValue(fromDate) &
                row.status.isNotValue(_skipped),
          ))
        .write(EventsCompanion(projectId: Value(projectId)));
  }

  /// Every non-skipped event linked to [projectId], oldest first.
  Future<List<EventRow>> eventsForProject(int projectId) =>
      (select(events)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .get();

  /// Stream version of [eventsForProject].
  Stream<List<EventRow>> watchForProject(int projectId) =>
      (select(events)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .watch();
}
