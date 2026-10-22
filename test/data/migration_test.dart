import 'package:drift_dev/api/migrations_native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

/// Every shipped schema version must upgrade to the current one without losing
/// data. The `drift_schemas/` dumps and `test/generated_migrations/` come from
/// `drift_dev schema dump` and `drift_dev schema generate`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Seconds since the epoch, which is how Drift stores a DateTime.
  final seconds = DateTime(2026, 10, 7).millisecondsSinceEpoch ~/ 1000;

  const insertEvent =
      'INSERT INTO events (date, title, tone_index, start_minute, end_minute, '
      'status, created_at, updated_at) ';

  test('version 1 upgrades to version 12', () async {
    final schema = await verifier.schemaAt(1);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 12);
  });

  test('version 2 upgrades to version 12', () async {
    final schema = await verifier.schemaAt(2);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 12);
  });

  test('version 3 upgrades to version 12', () async {
    final schema = await verifier.schemaAt(3);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 12);
  });

  test('upgrading from version 1 keeps the events that were stored', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(await database.sessionDao.running(), isNull);
  });

  test('upgrading from version 2 keeps events and sessions', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO sessions (event_id, started_at, planned_seconds, '
      'paused_seconds, active_seconds, overtime_seconds, outcome) '
      'VALUES (1, $seconds, 3600, 0, 0, 0, 0)',
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    final running = await database.sessionDao.running();
    expect(running, isNotNull);
    expect(running!.session.plannedSeconds, 3600);
    expect(await database.select(database.dayTemplates).get(), isEmpty);
  });

  test('upgrading from version 3 creates the progress tables empty', () async {
    final schema = await verifier.schemaAt(3);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 12);

    expect(await database.select(database.dayScores).get(), isEmpty);
    expect(await database.select(database.progress).get(), isEmpty);
    expect(await database.select(database.badgeUnlocks).get(), isEmpty);
    expect(await database.select(database.weeklyRoundups).get(), isEmpty);
  });

  test('a new install creates the same schema as the upgrade', () async {
    final schema = await verifier.schemaAt(4);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 12);
  });

  test(
    'upgrading from version 4 keeps events and defaults flight columns',
    () async {
      final schema = await verifier.schemaAt(4);
      schema.rawDatabase.execute(
        "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
      );

      final database = AppDatabase.forTesting(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 12);

      final events = await database.eventDao.eventsForDay(
        DateTime(2026, 10, 7),
      );
      expect(events.single.title, 'Deep work');
      expect(events.single.isFlight, isFalse);
      expect(events.single.flightNumber, isNull);
      expect(events.single.fromCode, isNull);
      expect(events.single.toCode, isNull);
    },
  );

  test('version 5 upgrades to version 12 with projects table', () async {
    final schema = await verifier.schemaAt(5);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);
    final projects = await database.projectDao.allProjects();
    expect(projects, isEmpty);
  });

  test('upgrading from version 5 reads old events as projectId null', () async {
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(events.single.projectId, isNull);
  });

  test('version 6 upgrades to version 7 with coach tables empty', () async {
    final schema = await verifier.schemaAt(6);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 7);
    final day = DateTime(2026, 10, 12);
    expect(await database.coachDao.intentFor(day), isNull);
    expect(await database.coachDao.insightsForWeek(2026, 42), isEmpty);
  });

  test('version 6 upgrades to version 12 with reflection columns defaulting null', () async {
    final schema = await verifier.schemaAt(6);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);
    final rows = await database.select(database.sessions).get();
    expect(rows, isEmpty);
  });

  test('upgrading from version 6 reads old sessions as not reflected', () async {
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO sessions (event_id, started_at, planned_seconds, '
      'paused_seconds, active_seconds, overtime_seconds, outcome) '
      'VALUES (1, $seconds, 3600, 0, 3600, 0, 1)',
    );
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);
    final sessions = await database.sessionDao.sessionsForEvent(1);
    expect(sessions.single.outcome, 1);
    expect(sessions.single.energyRating, isNull);
    expect(sessions.single.focusRating, isNull);
    expect(sessions.single.tagsCsv, isNull);
    expect(sessions.single.note, isNull);
  });

  test('version 8 upgrades to version 12 with predictedEnergy null', () async {
    final schema = await verifier.schemaAt(8);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);
    final day = DateTime(2026, 10, 12);
    await database.coachDao.upsertIntent(date: day, focusGoal: 'Old row');
    expect((await database.coachDao.intentFor(day))?.predictedEnergy, isNull);
  });

  test('version 9 upgrades to version 12 with notes null priority 0', () async {
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase.execute(
      'INSERT INTO projects (title, created_at, status) '
      "VALUES ('Portfolio', $seconds, 0)",
    );
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final projects = await database.projectDao.allProjects();
    expect(projects.single.title, 'Portfolio');
    expect(projects.single.notes, isNull);
    expect(projects.single.priority, 0);

    await database.resetAll();
    expect(await database.projectDao.allProjects(), isEmpty);
  });

  test('version 10 upgrades to version 12 with tasks empty', () async {
    final schema = await verifier.schemaAt(10);
    schema.rawDatabase.execute(
      'INSERT INTO projects (title, created_at, status) '
      "VALUES ('Portfolio', $seconds, 0)",
    );
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final projects = await database.projectDao.allProjects();
    expect(projects.single.title, 'Portfolio');
    expect(await database.select(database.tasks).get(), isEmpty);

    // resetAll clears the new table too.
    await database.into(database.tasks).insert(
      TasksCompanion.insert(
        projectId: projects.single.id,
        title: 'First step',
        sortOrder: 1,
        createdAt: DateTime(2026, 10, 7),
        updatedAt: DateTime(2026, 10, 7),
      ),
    );
    await database.resetAll();
    expect(await database.select(database.tasks).get(), isEmpty);
  });

  test('upgrading from version 11 turns subtasks into tasks', () async {
    final schema = await verifier.schemaAt(11);
    schema.rawDatabase.execute(
      'INSERT INTO projects (title, created_at, status, priority) '
      "VALUES ('Alpha', $seconds, 0, 0)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO project_subtasks (project_id, title, is_done, sort_order, created_at) '
      "VALUES (1, 'First step', 1, 1, $seconds), "
      "(1, 'Second step', 0, 2, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 12);

    final tasks = await database.select(database.tasks).get();
    expect(tasks.length, 2);
    final done = tasks.singleWhere((t) => t.title == 'First step');
    expect(done.boardStatus, 4);
    expect(done.completedAt, isNotNull);
    final open = tasks.singleWhere((t) => t.title == 'Second step');
    expect(open.boardStatus, 1);
    expect(open.completedAt, isNull);
    // The old table is gone: selecting it must throw.
    expect(
      () => schema.rawDatabase.select('SELECT * FROM project_subtasks'),
      throwsA(anything),
    );
  });
}
