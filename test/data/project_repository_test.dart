import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftProjectRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create trims the title', () async {
    final id = await repository.create('  Portfolio  ');
    expect((await db.projectDao.allProjects()).single.title, 'Portfolio');
    expect(id, isNonZero);
  });

  test('complete reopen and archive map to statuses', () async {
    final id = await repository.create('Portfolio');
    await repository.complete(id);
    expect((await db.projectDao.allProjects()).single.status, 1);
    await repository.reopen(id);
    expect((await db.projectDao.allProjects()).single.status, 0);
    await repository.archive(id);
    expect((await db.projectDao.allProjects()).single.status, 2);
  });

  test('updateDeadline updateTarget and updateAffinity persist', () async {
    final id = await repository.create('Portfolio');
    final deadline = DateTime(2026, 11, 1);
    await repository.updateDeadline(id, deadline);
    await repository.updateTarget(id, 600);
    await repository.updateAffinity(id, 1);
    final row = (await db.projectDao.allProjects()).single;
    expect(row.deadline, deadline);
    expect(row.targetMinutes, 600);
    expect(row.toneIndex, 1);
  });

  test('watchDetail emits planned minutes and done-only actuals', () async {
    final projectId = await repository.create('Portfolio');
    final now = DateTime(2026, 10, 14, 9);
    final eventId = await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 14),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
        projectId: Value(projectId),
      ),
    );
    await db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: now,
        plannedSeconds: 3600,
        activeSeconds: const Value(1800),
        outcome: Value(SessionOutcome.completed.dbIndex),
      ),
    );
    await db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: now,
        plannedSeconds: 3600,
        activeSeconds: const Value(3600),
        outcome: Value(SessionOutcome.abandoned.dbIndex),
      ),
    );

    final detail = await repository.watchDetail(projectId).first;

    expect(detail.project.id, projectId);
    expect(detail.events.map((e) => e.id), [eventId]);
    expect(detail.plannedMinutes, 60);
    expect(detail.actualMinutes, 30);
  });

  test('watchDetail groups sessions in one query with count and lastWorkedAt',
      () async {
    final projectId = await repository.create('Portfolio');
    final now = DateTime(2026, 10, 14, 9);
    Future<int> event(String title) => db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 14),
        title: title,
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
        projectId: Value(projectId),
      ),
    );
    Future<void> session(
      int eventId, {
      required DateTime endedAt,
      required int activeSeconds,
      required SessionOutcome outcome,
    }) => db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: endedAt.subtract(const Duration(hours: 1)),
        plannedSeconds: 3600,
        activeSeconds: Value(activeSeconds),
        endedAt: Value(endedAt),
        outcome: Value(outcome.dbIndex),
      ),
    );

    final first = await event('Deep work');
    final second = await event('Writing');
    await session(
      first,
      endedAt: DateTime(2026, 10, 14, 10),
      activeSeconds: 1800,
      outcome: SessionOutcome.completed,
    );
    await session(
      first,
      endedAt: DateTime(2026, 10, 14, 11),
      activeSeconds: 3600,
      outcome: SessionOutcome.abandoned,
    );
    await session(
      second,
      endedAt: DateTime(2026, 10, 15, 12),
      activeSeconds: 2700,
      outcome: SessionOutcome.completed,
    );
    await session(
      second,
      endedAt: DateTime(2026, 10, 16, 12),
      activeSeconds: 900,
      outcome: SessionOutcome.finishedEarly,
    );

    final detail = await repository.watchDetail(projectId).first;

    expect(detail.plannedMinutes, 120);
    // Done only: (1800 + 2700 + 900) ~/ 60; the abandoned 3600s excluded.
    expect(detail.actualMinutes, 90);
    expect(detail.sessionsCount, 3);
    expect(detail.lastWorkedAt, DateTime(2026, 10, 16, 12));
  });

  test('watchDetail with no events has zero sessions and null lastWorkedAt',
      () async {
    final projectId = await repository.create('Portfolio');

    final detail = await repository.watchDetail(projectId).first;

    expect(detail.events, isEmpty);
    expect(detail.plannedMinutes, 0);
    expect(detail.actualMinutes, 0);
    expect(detail.sessionsCount, 0);
    expect(detail.lastWorkedAt, isNull);
  });

  test('sessionsForProject returns every linked session in one round-trip',
      () async {
    final projectId = await repository.create('Portfolio');
    final now = DateTime(2026, 10, 14, 9);
    Future<int> event(String title) => db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 14),
        title: title,
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
        projectId: Value(projectId),
      ),
    );
    final first = await event('Deep work');
    final second = await event('Writing');
    for (final eventId in [first, second]) {
      await db.sessionDao.insertSession(
        SessionsCompanion.insert(
          eventId: eventId,
          startedAt: now,
          plannedSeconds: 3600,
          activeSeconds: const Value(600),
          outcome: Value(SessionOutcome.completed.dbIndex),
        ),
      );
    }

    final sessions = await db.sessionDao.sessionsForProject([first, second]);

    expect(sessions.map((s) => s.eventId).toSet(), {first, second});
    expect(sessions, hasLength(2));
    expect(await db.sessionDao.sessionsForProject(const []), isEmpty);
  });

  test('deleteAndUnlink removes the project', () async {
    final id = await repository.create('Portfolio');
    await repository.deleteAndUnlink(id);
    expect(await db.projectDao.allProjects(), isEmpty);
  });

  test('complete then archive retains completedAt', () async {
    final id = await repository.create('Portfolio');
    await repository.complete(id);
    final completedAt =
        (await db.projectDao.allProjects()).single.completedAt;
    expect(completedAt, isNotNull);

    await repository.archive(id);

    final row = (await db.projectDao.allProjects()).single;
    expect(row.status, 2);
    expect(row.completedAt, completedAt);
  });

  test('watchDetail exposes done-only sessions for velocity and actuals',
      () async {
    final projectId = await repository.create('Portfolio');
    final now = DateTime(2026, 10, 14, 9);
    Future<int> event(String title) => db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 14),
        title: title,
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
        projectId: Value(projectId),
      ),
    );
    Future<void> session(
      int eventId, {
      required int activeSeconds,
      required SessionOutcome outcome,
    }) => db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: now,
        plannedSeconds: 3600,
        activeSeconds: Value(activeSeconds),
        endedAt: Value(now.add(const Duration(minutes: 30))),
        outcome: Value(outcome.dbIndex),
      ),
    );

    final first = await event('Deep work');
    final second = await event('Writing');
    await session(
      first,
      activeSeconds: 1800,
      outcome: SessionOutcome.completed,
    );
    await session(
      first,
      activeSeconds: 3600,
      outcome: SessionOutcome.abandoned,
    );
    await session(
      second,
      activeSeconds: 900,
      outcome: SessionOutcome.finishedEarly,
    );

    final detail = await repository.watchDetail(projectId).first;

    // Done outcomes only: abandoned excluded, matching actualMinutes math.
    expect(detail.doneSessions, hasLength(2));
    expect(
      detail.doneSessions.map((s) => s.outcome).toSet(),
      {SessionOutcome.completed.dbIndex, SessionOutcome.finishedEarly.dbIndex},
    );
    expect(detail.doneSessions.map((s) => s.eventId).toSet(), {first, second});
  });

  test('unarchive restores an active project with null completedAt', () async {
    final id = await repository.create('Portfolio');
    await repository.archive(id);
    expect((await db.projectDao.allProjects()).single.status, 2);

    await repository.unarchive(id);

    final row = (await db.projectDao.allProjects()).single;
    expect(row.status, 0);
    expect(row.completedAt, isNull);
  });

  test('unarchive restores a completed project preserving completedAt',
      () async {
    final id = await repository.create('Portfolio');
    await repository.complete(id);
    final completedAt =
        (await db.projectDao.allProjects()).single.completedAt;
    await repository.archive(id);

    await repository.unarchive(id);

    final row = (await db.projectDao.allProjects()).single;
    expect(row.status, 1);
    expect(row.completedAt, completedAt);
  });

  test('watchProjects emits the created project', () async {
    await db.projectDao.allProjects(); // prime; cf. event_dao_test.dart
    final future = repository.watchProjects().take(2).toList();
    await repository.create('Portfolio');
    final batches = await future;
    expect(batches.first, isEmpty);
    expect(batches.last.single.title, 'Portfolio');
  });
}
