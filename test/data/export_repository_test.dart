import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/export_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftExportRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftExportRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('the export holds every table as JSON', () async {
    final now = DateTime(2026, 10, 7, 12);
    await db.settingsDao.setValue('theme_mode', 'dark');
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 7),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final decoded =
        jsonDecode(await repository.buildJson()) as Map<String, Object?>;
    expect(
      decoded.keys,
      containsAll([
        'exportedAt',
        'settings',
        'events',
        'eventSeries',
        'sessions',
        'dayTemplates',
        'dayScores',
        'progress',
        'badgeUnlocks',
        'weeklyRoundups',
      ]),
    );
    expect((decoded['settings'] as Map)['theme_mode'], 'dark');
    expect((decoded['events'] as List), hasLength(1));
  });

  test('the temp file round-trips its contents', () async {
    const contents = '{"hello": "world"}';
    final path = await repository.writeTempFile(contents);
    addTearDown(() => File(path).delete());

    expect(path, endsWith('.json'));
    expect(await File(path).readAsString(), contents);
  });

  test('resetAll wipes every row and keeps the schema usable', () async {
    final now = DateTime(2026, 10, 7, 12);
    await db.settingsDao.setValue('theme_mode', 'dark');
    final eventId = await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 7),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: now,
        plannedSeconds: 3600,
      ),
    );
    await db.progressDao.upsertProgress(
      ProgressCompanion.insert(id: const Value(1)),
    );

    await db.resetAll();

    expect(await db.settingsDao.valueFor('theme_mode'), isNull);
    expect(await db.eventDao.eventsForDay(DateTime(2026, 10, 7)), isEmpty);
    expect(await db.sessionDao.running(), isNull);
    expect(await db.progressDao.progressRow(), isNull);
    expect(await db.select(db.dayScores).get(), isEmpty);
    expect(await db.select(db.badgeUnlocks).get(), isEmpty);
    expect(await db.select(db.weeklyRoundups).get(), isEmpty);

    // The schema survives: new rows insert cleanly.
    await db.settingsDao.setValue('theme_mode', 'light');
    expect(await db.settingsDao.valueFor('theme_mode'), 'light');
  });

  test('resetAll clears projects', () async {
    final now = DateTime(2026, 10, 7, 12);
    await db.projectDao.createProject(
      ProjectsCompanion.insert(title: 'Portfolio', createdAt: now),
    );
    expect(await db.projectDao.allProjects(), hasLength(1));

    await db.resetAll();

    expect(await db.projectDao.allProjects(), isEmpty);
  });
}
