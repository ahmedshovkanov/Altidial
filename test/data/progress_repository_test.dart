import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository repository;
  DateTime now = DateTime(2026, 10, 7, 18);

  final monday = DateTime(2026, 10, 5);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 7, 18);
    repository = DriftProgressRepository(db, now: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 660,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    SessionOutcome outcome = SessionOutcome.completed,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 7, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(outcome.dbIndex),
    ),
  );

  test('ending a session writes the day score and the progress row', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id, activeSeconds: 5400);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final score = await db.progressDao.dayScoreFor(DateTime(2026, 10, 7));
    expect(score, isNotNull);
    // 120 planned, 90 completed: 38 adherence; 90 focus of 180: 15; one tone: 0.
    expect(score!.energyScore, 53);
    expect(score.focusMinutes, 90);
    expect(score.plannedMinutes, 120);
    final progress = await db.progressDao.progressRow();
    expect(progress, isNotNull);
    expect(progress!.currentStreak, 1);
    // 90 focus minutes pay 135 XP plus 50 each for first_session and the
    // clean week: level 2.
    expect(progress.xp, 235);
    expect(progress.level, 2);
    expect(progress.lastStreakDate, DateTime(2026, 10, 7));
  });

  test('the first ended session unlocks the first badge', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await repository.onSessionEnded(monday);

    // A single ended session also completes a clean week (≥1 ended, 0
    // abandoned), so both badges unlock together.
    expect(await db.progressDao.unlockedBadgeIds(), [
      'first_session',
      'week_no_abandoned',
    ]);
  });

  test('consecutive qualifying days build the streak', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.onSessionEnded(DateTime(2026, 10, 6));

    final progress = await db.progressDao.progressRow();
    expect(progress!.currentStreak, 2);
    expect(progress.longestStreak, 2);
  });

  test('ensureFresh finalises yesterday after the day rolls over', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.onSessionEnded(DateTime(2026, 10, 6));
    expect((await db.progressDao.progressRow())!.currentStreak, 2);

    now = DateTime(2026, 10, 9, 8);
    await repository.ensureFresh();

    final progress = await db.progressDao.progressRow();
    expect(progress!.currentStreak, 0);
    expect(progress.longestStreak, 2);
    expect(progress.lastStreakDate, DateTime(2026, 10, 9));
    // Yesterday had nothing: no row was invented for it.
    expect(await db.progressDao.dayScoreFor(DateTime(2026, 10, 8)), isNull);
  });

  test('a fresh progress row needs no work', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 7)));
    await repository.onSessionEnded(DateTime(2026, 10, 7));
    final progress = await db.progressDao.progressRow();

    await repository.ensureFresh();
    expect(await db.progressDao.progressRow(), progress);
  });

  test('past day scores are never silently recomputed', () async {
    final id = await seedEvent(date: monday);
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(monday);
    final frozen = await db.progressDao.dayScoreFor(monday);

    now = DateTime(2026, 10, 6, 18);
    await seedSession(
      eventId: await seedEvent(date: DateTime(2026, 10, 6)),
      activeSeconds: 7200,
      startedAt: DateTime(2026, 10, 6, 9),
    );
    await repository.onSessionEnded(DateTime(2026, 10, 6));

    final reread = await db.progressDao.dayScoreFor(monday);
    expect(reread!.computedAt, frozen!.computedAt);
    expect(reread.energyScore, frozen.energyScore);
  });

  test('recalculateAll rebuilds every row from source', () async {
    final id = await seedEvent(date: monday, start: 540, end: 660);
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(monday);
    final before = await db.progressDao.dayScoreFor(monday);

    await db.progressDao.clearDayScores();
    expect(await db.progressDao.dayScoreFor(monday), isNull);
    await repository.recalculateAll();

    final after = await db.progressDao.dayScoreFor(monday);
    expect(after!.energyScore, before!.energyScore);
    expect(after.focusMinutes, before.focusMinutes);
    // Monday alone with today Wednesday: the run ended two days ago, so the
    // current streak is 0 but the longest run is preserved.
    expect((await db.progressDao.progressRow())!.currentStreak, 0);
    expect(await db.progressDao.unlockedBadgeIds(), [
      'first_session',
      'week_no_abandoned',
    ]);
  });

  test('the stored focus target scales focus points', () async {
    await db.settingsDao.setValue('daily_focus_target', '60');
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final score = await db.progressDao.dayScoreFor(DateTime(2026, 10, 7));
    expect(score!.focusPoints, 30);
  });

  test('progress watches emit on session end', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id);
    final emissions = repository.watchProgress().take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final rows = await emissions;
    expect(rows.first, isNull);
    expect(rows.last!.currentStreak, 1);
  });
}
