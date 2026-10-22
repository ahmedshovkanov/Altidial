import 'package:drift/drift.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/sessions_table.dart';

part 'stats_dao.g.dart';

/// Grouped statistics over `events ⋈ sessions` (spec §8). Every query filters
/// to one window, attributes minutes to the event's local date, and counts
/// only `completed` and `finishedEarly` sessions. Minutes are derived from the
/// returned seconds in the repository, after grouping.
@DriftAccessor(tables: [Events, Sessions])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.attachedDatabase);

  /// `events.status == 2` is a deleted occurrence of a series (see EventDao):
  /// it contributes nothing to any total.
  static const _skipped = 2;

  Expression<bool> get _countsAsDone => sessions.outcome.isIn([
    SessionOutcome.completed.dbIndex,
    SessionOutcome.finishedEarly.dbIndex,
  ]);

  Expression<bool> _inWindow(DateTime from, DateTime toExclusive) =>
      events.date.isBiggerOrEqualValue(from) &
      events.date.isSmallerThanValue(toExclusive) &
      events.status.isNotValue(_skipped);

  /// `countsAsDone` seconds per (event date, tone): one row per cell that has
  /// sessions.
  Future<List<({DateTime date, int toneIndex, int seconds})>> toneSecondsByDay(
    DateTime from,
    DateTime toExclusive,
  ) {
    final seconds = sessions.activeSeconds.sum();
    final query = selectOnly(events)
      ..addColumns([events.date, events.toneIndex, seconds])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..where(_inWindow(from, toExclusive) & _countsAsDone)
      ..groupBy([events.date, events.toneIndex]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
            seconds: row.read(seconds) ?? 0,
          ),
        )
        .get();
  }

  /// Planned whole minutes per tone, for every stored event regardless of
  /// sessions. Overlapping events count twice, like the Calendar's rings.
  Future<List<({int toneIndex, int minutes})>> plannedMinutesByTone(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query = selectOnly(events)
      ..addColumns([events.toneIndex, minutes])
      ..where(_inWindow(from, toExclusive))
      ..groupBy([events.toneIndex]);
    return query
        .map(
          (row) => (
            toneIndex: row.read(events.toneIndex)!,
            minutes: row.read(minutes) ?? 0,
          ),
        )
        .get();
  }

  /// `(startedAt, activeSeconds)` of every `countsAsDone` session on [toneIndex]
  /// in the window, oldest first. The heatmap buckets these in Dart.
  Future<List<({DateTime startedAt, int activeSeconds})>> focusInstants(
    DateTime from,
    DateTime toExclusive,
    int toneIndex,
  ) {
    final query =
        select(
            sessions,
          ).join([innerJoin(events, events.id.equalsExp(sessions.eventId))])
          ..where(
            _inWindow(from, toExclusive) &
                events.toneIndex.equals(toneIndex) &
                _countsAsDone,
          )
          ..orderBy([OrderingTerm.asc(sessions.startedAt)]);
    return query.map((row) {
      final session = row.readTable(sessions);
      return (
        startedAt: session.startedAt,
        activeSeconds: session.activeSeconds,
      );
    }).get();
  }

  /// Ended versus abandoned sessions on [toneIndex] in the window: the two
  /// denominators the focus section rates with.
  Future<({int ended, int abandoned})> focusOutcomeCounts(
    DateTime from,
    DateTime toExclusive,
    int toneIndex,
  ) {
    final ended = countAll(
      filter: sessions.outcome.isNotValue(SessionOutcome.running.dbIndex),
    );
    final abandoned = countAll(
      filter: sessions.outcome.equals(SessionOutcome.abandoned.dbIndex),
    );
    final query = selectOnly(events)
      ..addColumns([ended, abandoned])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..where(
        _inWindow(from, toExclusive) &
            events.toneIndex.equals(toneIndex) &
            sessions.outcome.isNotValue(SessionOutcome.running.dbIndex),
      );
    return query
        .map(
          (row) => (
            ended: row.read(ended) ?? 0,
            abandoned: row.read(abandoned) ?? 0,
          ),
        )
        .getSingle();
  }
}
