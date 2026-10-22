import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  final now = DateTime(2026, 10, 14, 9, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createProject(String title) => db.projectDao.createProject(
    ProjectsCompanion.insert(title: title, createdAt: now),
  );

  EventsCompanion eventOn(DateTime date, String title, {int? projectId}) {
    return EventsCompanion.insert(
      date: date,
      title: title,
      toneIndex: 0,
      startMinute: 540,
      endMinute: 600,
      createdAt: now,
      updatedAt: now,
      projectId: Value(projectId),
    );
  }

  test('create project then allProjects returns it', () async {
    final id = await createProject('Portfolio');
    expect(id, isNonZero);
    final all = await db.projectDao.allProjects();
    expect(all.single.title, 'Portfolio');
  });

  test('updateDeadline updateTarget and updateAffinity persist', () async {
    final id = await createProject('Portfolio');
    await db.projectDao.updateDeadline(id, DateTime(2026, 11, 1));
    await db.projectDao.updateTarget(id, 600);
    await db.projectDao.updateAffinity(id, 1);
    final row = (await db.projectDao.allProjects()).single;
    expect(row.deadline, DateTime(2026, 11, 1));
    expect(row.targetMinutes, 600);
    expect(row.toneIndex, 1);
  });

  test('setStatus marks complete then reopen clears it', () async {
    final id = await createProject('Portfolio');
    await db.projectDao.setStatus(id, 1, now);
    expect((await db.projectDao.allProjects()).single.status, 1);
    await db.projectDao.setStatus(id, 0, null);
    final row = (await db.projectDao.allProjects()).single;
    expect(row.status, 0);
    expect(row.completedAt, isNull);
  });

  test('deleteAndUnlink removes project but keeps events unlinked', () async {
    final id = await createProject('Portfolio');
    final day = DateTime(2026, 10, 14);
    final eventId = await db.eventDao.insertEvent(
      eventOn(day, 'Deep work', projectId: id),
    );
    await db.projectDao.deleteAndUnlink(id);
    expect(await db.projectDao.allProjects(), isEmpty);
    final events = await db.eventDao.eventsForDay(day);
    expect(events, hasLength(1));
    expect(events.single.id, eventId);
    expect(events.single.projectId, isNull);
  });

  test('updateProject links and eventsForProject reads back', () async {
    final id = await createProject('Portfolio');
    final day = DateTime(2026, 10, 14);
    final eventId = await db.eventDao.insertEvent(eventOn(day, 'Deep work'));
    await db.eventDao.updateProject(id: eventId, projectId: id);
    final linked = await db.eventDao.eventsForProject(id);
    expect(linked.map((e) => e.id), [eventId]);
  });

  test('updateProjectForSeries links a series from a date onward', () async {
    final id = await createProject('Portfolio');
    final seriesId = await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: 1,
        validFrom: DateTime(2026, 10, 13),
        createdAt: now,
      ),
    );
    Future<int> occurrence(DateTime date, String title) =>
        db.eventDao.insertEvent(
          EventsCompanion.insert(
            seriesId: Value(seriesId),
            date: date,
            title: title,
            toneIndex: 0,
            startMinute: 540,
            endMinute: 570,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final before = await occurrence(DateTime(2026, 10, 13), 'Before');
    final onDay = await occurrence(DateTime(2026, 10, 14), 'On day');
    final after = await occurrence(DateTime(2026, 10, 15), 'After');

    await db.eventDao.updateProjectForSeries(
      seriesId: seriesId,
      fromDate: DateTime(2026, 10, 14),
      projectId: id,
    );

    final rows = await db.eventDao.eventsForProject(id);
    expect(rows.map((e) => e.id), containsAll([onDay, after]));
    expect(rows.map((e) => e.id), isNot(contains(before)));
  });

  test('watchProjects emits again after insert', () async {
    // Prime the connection: see the watchDay note in event_dao_test.dart.
    await db.projectDao.allProjects();

    final future = db.projectDao.watchProjects().take(2).toList();

    await createProject('Portfolio');

    final batches = await future;
    expect(batches.first, isEmpty);
    expect(batches.last.single.title, 'Portfolio');
  });

  test('rename/notes/priority round-trip', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.projectDao.createProject(
      ProjectsCompanion.insert(title: 'Alpha', createdAt: DateTime(2026, 10, 1)),
    );
    await db.projectDao.updateTitle(id, 'Beta');
    await db.projectDao.updateNotes(id, 'Why it matters');
    await db.projectDao.updatePriority(id, 2);
    final row = await (db.select(db.projects)..where((r) => r.id.equals(id))).getSingle();
    expect(row.title, 'Beta');
    expect(row.notes, 'Why it matters');
    expect(row.priority, 2);
  });
}
