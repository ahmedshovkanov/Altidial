import 'package:drift/drift.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/day_scores_table.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/progress_table.dart';
import 'package:altidial/data/tables/sessions_table.dart';
import 'package:altidial/data/tables/weekly_roundups_table.dart';

part 'progress_dao.g.dart';

/// Reads and writes the progress caches, and the source-table aggregates the
/// progress evaluation needs (spec §9.1). Everything recomputable lives behind
/// `recalculateAll()` in the repository; this DAO only moves rows.
@DriftAccessor(
  tables: [DayScores, Progress, BadgeUnlocks, WeeklyRoundups, Sessions, Events],
)
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.attachedDatabase);

  static const _skipped = 2;

  static int get _running => SessionOutcome.running.dbIndex;
  Expression<bool> get _countsAsDone => sessions.outcome.isIn([
    SessionOutcome.completed.dbIndex,
    SessionOutcome.finishedEarly.dbIndex,
  ]);

  Future<DayScoreRow?> dayScoreFor(DateTime date) => (select(
    dayScores,
  )..where((row) => row.date.equals(date))).getSingleOrNull();

  Future<void> upsertDayScore(DayScoresCompanion row) =>
      into(dayScores).insertOnConflictUpdate(row);

  Future<void> deleteDayScore(DateTime date) =>
      (delete(dayScores)..where((row) => row.date.equals(date))).go();

  Future<void> clearDayScores() => delete(dayScores).go();

  Future<ProgressRow?> progressRow() =>
      (select(progress)..where((row) => row.id.equals(1))).getSingleOrNull();

  Future<void> upsertProgress(ProgressCompanion row) =>
      into(progress).insertOnConflictUpdate(row);

  Future<List<String>> unlockedBadgeIds() =>
      (select(badgeUnlocks)
            ..orderBy([(row) => OrderingTerm.asc(row.unlockedAt)]))
          .map((row) => row.badgeId)
          .get();

  Future<void> unlockBadges(List<String> ids, DateTime now) => batch((batch) {
    for (final id in ids) {
      batch.insert(
        badgeUnlocks,
        BadgeUnlocksCompanion.insert(badgeId: id, unlockedAt: now),
        mode: InsertMode.insertOrReplace,
      );
    }
  });

  Stream<ProgressRow?> watchProgress() =>
      (select(progress)..where((row) => row.id.equals(1))).watchSingleOrNull();

  Stream<DayScoreRow?> watchDayScore(DateTime date) => (select(
    dayScores,
  )..where((row) => row.date.equals(date))).watchSingleOrNull();

  Stream<List<BadgeUnlockRow>> watchBadges() => (select(
    badgeUnlocks,
  )..orderBy([(row) => OrderingTerm.asc(row.unlockedAt)])).watch();

  /// Planned whole minutes per date in `[from, toExclusive)`, skipping deleted
  /// occurrences.
  Future<List<({DateTime date, int minutes})>> plannedMinutesByDay(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query = selectOnly(events)
      ..addColumns([events.date, minutes])
      ..where(
        events.date.isBiggerOrEqualValue(from) &
            events.date.isSmallerThanValue(toExclusive) &
            events.status.isNotValue(_skipped),
      )
      ..groupBy([events.date]);
    return query
        .map(
          (row) =>
              (date: row.read(events.date)!, minutes: row.read(minutes) ?? 0),
        )
        .get();
  }

  /// Every local midnight that has an event, ascending. Sessions always belong
  /// to an event, so this is every day `recalculateAll()` must visit.
  Future<List<DateTime>> datesWithData() {
    final query = selectOnly(events, distinct: true)
      ..addColumns([events.date])
      ..orderBy([OrderingTerm.asc(events.date)]);
    return query.map((row) => row.read(events.date)!).get();
  }

  Future<int> endedSessionCount() {
    final ended = countAll(filter: sessions.outcome.isNotValue(_running));
    final query = selectOnly(sessions)..addColumns([ended]);
    return query.map((row) => row.read(ended) ?? 0).getSingle();
  }

  /// Distinct event dates with a `countsAsDone` session, ascending.
  Future<List<DateTime>> qualifyingDates() {
    final query = selectOnly(events, distinct: true)
      ..addColumns([events.date])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..where(_countsAsDone)
      ..orderBy([OrderingTerm.asc(events.date)]);
    return query.map((row) => row.read(events.date)!).get();
  }

  /// `countsAsDone` focus seconds per date, all time.
  Future<List<({DateTime date, int seconds})>> focusSecondsByDay() {
    final seconds = sessions.activeSeconds.sum();
    final query = selectOnly(events)
      ..addColumns([events.date, seconds])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..where(
        events.status.isNotValue(_skipped) &
            events.toneIndex.equals(0) &
            _countsAsDone,
      )
      ..groupBy([events.date]);
    return query
        .map(
          (row) =>
              (date: row.read(events.date)!, seconds: row.read(seconds) ?? 0),
        )
        .get();
  }

  /// `countsAsDone` seconds per (date, tone), all time. Weeks fold in Dart.
  Future<List<({DateTime date, int toneIndex, int seconds})>> tonePresence() {
    final seconds = sessions.activeSeconds.sum();
    final query = selectOnly(events)
      ..addColumns([events.date, events.toneIndex, seconds])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..where(events.status.isNotValue(_skipped) & _countsAsDone)
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

  /// Per date, all time: ended sessions and abandoned sessions.
  Future<List<({DateTime date, int ended, int abandoned})>> dayOutcomes() {
    final ended = countAll(filter: sessions.outcome.isNotValue(_running));
    final abandoned = countAll(
      filter: sessions.outcome.equals(SessionOutcome.abandoned.dbIndex),
    );
    final query = selectOnly(events)
      ..addColumns([events.date, ended, abandoned])
      ..join([innerJoin(sessions, sessions.eventId.equalsExp(events.id))])
      ..groupBy([events.date]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            ended: row.read(ended) ?? 0,
            abandoned: row.read(abandoned) ?? 0,
          ),
        )
        .get();
  }

  /// When every `countsAsDone` focus session began. Hours bucket in Dart.
  Future<List<DateTime>> focusStartTimes() {
    final query = selectOnly(sessions)
      ..addColumns([sessions.startedAt])
      ..join([innerJoin(events, events.id.equalsExp(sessions.eventId))])
      ..where(events.toneIndex.equals(0) & _countsAsDone);
    return query.map((row) => row.read(sessions.startedAt)!).get();
  }

  /// Every `countsAsDone` session's seconds with its event's tone.
  Future<List<({int seconds, int toneIndex})>> sessionXpInputs() {
    final query = select(sessions).join([
      innerJoin(events, events.id.equalsExp(sessions.eventId)),
    ])..where(_countsAsDone);
    return query
        .map(
          (row) => (
            seconds: row.readTable(sessions).activeSeconds,
            toneIndex: row.readTable(events).toneIndex,
          ),
        )
        .get();
  }
}
