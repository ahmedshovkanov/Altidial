import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeriesMaterialiser materialiser;
  late ReuseRepository reuse;
  late EventRepository events;

  final created = DateTime(2026, 10, 1, 9);
  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);

  Future<int> addSeries() {
    final rule = RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: 2,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: rule.kind.dbIndex,
        weekdayMask: Value(rule.weekdayMask),
        validFrom: monday,
        validUntil: Value(rule.until),
        createdAt: created,
      ),
    );
  }

  Future<int> addProject() => db.projectDao.createProject(
    ProjectsCompanion.insert(title: 'Portfolio', createdAt: created),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    materialiser = SeriesMaterialiser(db.seriesDao, clock: () => created);
    reuse = DriftReuseRepository(db.templateDao, clock: () => created);
    events = DriftEventRepository(db.eventDao, clock: () => created);
  });

  tearDown(() async {
    await db.close();
  });

  test('linked event round-trips projectId through CalendarEvent.fromRow',
      () async {
    final projectId = await addProject();
    final id = await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: monday,
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        projectId: Value(projectId),
        createdAt: created,
        updatedAt: created,
      ),
    );

    final rows = await db.eventDao.eventsForDay(monday);
    expect(rows.single.projectId, projectId);

    final event = CalendarEvent.fromRow(rows.single);
    expect(event.projectId, projectId);

    expect(await db.eventDao.eventsForProject(projectId), hasLength(1));

    await db.eventDao.updateProject(id: id, projectId: null);
    final unlinked = await db.eventDao.eventsForDay(monday);
    expect(CalendarEvent.fromRow(unlinked.single).projectId, isNull);
  });

  test('EventRepository.createEvent stores projectId and updateProject relinks',
      () async {
    final projectId = await addProject();

    final id = await events.createEvent(
      day: monday,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
      projectId: projectId,
    );

    expect((await events.eventsForDay(monday)).single.projectId, projectId);

    await events.updateProject(id: id, projectId: null);
    expect(
      (await events.eventsForDay(monday)).single.projectId,
      isNull,
    );

    await events.updateProject(id: id, projectId: projectId);
    expect(
      (await events.eventsForDay(monday)).single.projectId,
      projectId,
    );
  });

  test('copyDay inherits projectId', () async {
    final projectId = await addProject();
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: monday,
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        projectId: Value(projectId),
        createdAt: created,
        updatedAt: created,
      ),
    );
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: monday,
        title: 'Unlinked',
        toneIndex: 1,
        startMinute: 700,
        endMinute: 730,
        createdAt: created,
        updatedAt: created,
      ),
    );

    expect(await reuse.copyDay(from: monday, to: tuesday), 2);

    final copied = await db.eventDao.eventsForDay(tuesday);
    expect(copied, hasLength(2));
    expect(
      copied.firstWhere((row) => row.title == 'Deep work').projectId,
      projectId,
    );
    expect(
      copied.firstWhere((row) => row.title == 'Unlinked').projectId,
      isNull,
    );
  });

  test('materialised occurrences start unlinked (series carry no project)',
      () async {
    await addSeries();

    await materialiser.materialiseDay(monday);

    final rows = await db.eventDao.eventsForDay(monday);
    expect(rows, hasLength(1));
    expect(rows.single.seriesId, isNotNull);
    expect(rows.single.projectId, isNull);
    expect(CalendarEvent.fromRow(rows.single).projectId, isNull);
  });
}
