import 'package:drift/drift.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/sessions_table.dart';

part 'session_dao.g.dart';

/// A running session together with the event it times.
typedef RunningRow = ({SessionRow session, EventRow event});

@DriftAccessor(tables: [Sessions, Events])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _runningQuery() =>
      select(
          sessions,
        ).join([innerJoin(events, events.id.equalsExp(sessions.eventId))])
        ..where(sessions.outcome.equals(SessionOutcome.running.dbIndex))
        ..orderBy([OrderingTerm.desc(sessions.startedAt)]);

  RunningRow _toRunning(TypedResult row) =>
      (session: row.readTable(sessions), event: row.readTable(events));

  /// The running session, or null. Emits again whenever the session or its
  /// event changes. If corrupt data ever left two running rows, the newest
  /// wins.
  Stream<RunningRow?> watchRunning() => _runningQuery().watch().map(
    (rows) => rows.isEmpty ? null : _toRunning(rows.first),
  );

  Future<RunningRow?> running() async {
    final rows = await _runningQuery().get();
    return rows.isEmpty ? null : _toRunning(rows.first);
  }

  Future<SessionRow?> sessionById(int id) =>
      (select(sessions)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<EventRow?> eventById(int id) =>
      (select(events)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<int> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry);

  Future<void> updateSession(int id, SessionsCompanion changes) =>
      (update(sessions)..where((row) => row.id.equals(id))).write(changes);

  Future<void> setEventStatus({
    required int eventId,
    required int status,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(eventId))).write(
      EventsCompanion(status: Value(status), updatedAt: Value(updatedAt)),
    );
  }

  /// Every session of an event, newest first.
  Future<List<SessionRow>> sessionsForEvent(int eventId) =>
      (select(sessions)
            ..where((row) => row.eventId.equals(eventId))
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .get();

  /// Every session linked to any of [eventIds] in one round-trip — the
  /// grouped backing query for the project detail (replaces the per-event
  /// `sessionsForEvent` loop). Empty input matches nothing.
  Future<List<SessionRow>> sessionsForProject(List<int> eventIds) {
    if (eventIds.isEmpty) return Future.value(<SessionRow>[]);
    return (select(sessions)..where((s) => s.eventId.isIn(eventIds))).get();
  }

  Future<void> updateReflection({
    required int sessionId,
    required int? energyRating,
    required int? focusRating,
    required String? tagsCsv,
    required String? note,
  }) => (update(sessions)..where((row) => row.id.equals(sessionId))).write(
    SessionsCompanion(
      energyRating: Value(energyRating),
      focusRating: Value(focusRating),
      tagsCsv: Value(tagsCsv),
      note: Value(note),
    ),
  );

  /// Every ended session, newest first. Powers the journal timeline.
  Future<List<SessionRow>> endedSessions() =>
      (select(sessions)
            ..where((row) => row.endedAt.isNotNull())
            ..orderBy([(row) => OrderingTerm.desc(row.endedAt)])
            ..limit(500))
          .get();

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
