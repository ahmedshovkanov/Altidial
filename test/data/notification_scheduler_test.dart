import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/repositories/notification_scheduler.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late FakeNotificationService service;
  late DriftNotificationScheduler scheduler;

  // Wednesday 7 October 2026, 10:30.
  final now = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FakeNotificationService();
    scheduler = DriftNotificationScheduler(
      db,
      service,
      now: () => now,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent(DateTime date, {int start = 720}) =>
      db.eventDao.insertEvent(
        EventsCompanion.insert(
          date: date,
          title: 'Deep work',
          toneIndex: Tone.focus.dbIndex,
          startMinute: start,
          endMinute: start + 60,
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('a morning reconcile schedules the event, the mornings and the roundup', () async {
    await seedEvent(DateTime(2026, 10, 7));

    await scheduler.reconcile();

    expect(service.pending[10001]?.at, DateTime(2026, 10, 7, 11, 50));
    // Today is full; tomorrow empty at the default 08:00.
    expect(service.pending[20281008]?.at, DateTime(2026, 10, 8, 8));
    expect(service.pending[30001]?.at, DateTime(2026, 10, 11, 20));
  });

  test('a second pass schedules nothing new', () async {
    await seedEvent(DateTime(2026, 10, 7));
    await scheduler.reconcile();
    final calls = service.log.where((line) => line.startsWith('schedule')).length;

    await scheduler.reconcile();

    expect(
      service.log.where((line) => line.startsWith('schedule')).length,
      calls,
    );
  });

  test('a deleted event loses its reminder', () async {
    final id = await seedEvent(DateTime(2026, 10, 7));
    await scheduler.reconcile();
    expect(service.pending, contains(10000 + id));

    await db.eventDao.deleteById(id, now: now);
    await scheduler.reconcile();

    expect(service.pending, isNot(contains(10000 + id)));
  });

  test('a switched-off type cancels even with no memory of it', () async {
    // A previous launch scheduled this; this scheduler never saw it.
    service.pending[10001] = (
      at: DateTime(2026, 10, 7, 11, 50),
      title: 'Deep work',
      body: 'x',
    );
    await seedEvent(DateTime(2026, 10, 7));
    await db.settingsDao.setValue(notifyEventSoonKey, '0');

    await DriftNotificationScheduler(db, service, now: () => now).reconcile();

    expect(service.pending, isNot(contains(10001)));
    // The roundup (a type still on) is scheduled by the same pass.
    expect(service.pending, contains(30001));
  });

  test('a failing plugin is swallowed and retried next pass', () async {
    await seedEvent(DateTime(2026, 10, 7));
    service.failSchedule = true;

    await scheduler.reconcile();
    expect(service.pending, isEmpty);

    service.failSchedule = false;
    await scheduler.reconcile();
    expect(service.pending, contains(10001));
  });

  test('materialising first pulls series occurrences into range', () async {
    // A daily series starting today: no occurrence rows exist until the
    // materialiser runs inside reconcile.
    final rule = RecurrenceRule.daily();
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.life.dbIndex,
        startMinute: 540,
        endMinute: 555,
        recurrenceKind: rule.kind.dbIndex,
        weekdayMask: Value(rule.weekdayMask),
        validFrom: DateTime(2026, 10, 7),
        validUntil: const Value(null),
        createdAt: now,
      ),
    );
    scheduler = DriftNotificationScheduler(
      db,
      service,
      now: () => now,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => now),
    );

    await scheduler.reconcile();

    // Seven occurrences (7–13 Oct); today's 08:50 reminder already passed, so
    // six stay pending — including tomorrow's 08:50.
    final reminders = service.pending.keys.where(
      (id) => id >= 10000 && id < 20000,
    );
    expect(reminders, hasLength(6));
    final tomorrow = await db.eventDao.eventsForDay(DateTime(2026, 10, 8));
    expect(
      service.pending[10000 + tomorrow.single.id]?.at,
      DateTime(2026, 10, 8, 8, 50),
    );
  });

  test('an active project deadline schedules 09:00 the day before', () async {
    final id = await db.projectDao.createProject(
      ProjectsCompanion.insert(
        title: 'Alpha',
        createdAt: now,
        deadline: Value(DateTime(2026, 10, 20)),
      ),
    );

    await scheduler.reconcile();

    expect(service.pending[40000 + id]?.at, DateTime(2026, 10, 19, 9));
  });

  test('completing a project cancels its deadline reminder', () async {
    final id = await db.projectDao.createProject(
      ProjectsCompanion.insert(
        title: 'Alpha',
        createdAt: now,
        deadline: Value(DateTime(2026, 10, 20)),
      ),
    );
    await scheduler.reconcile();
    expect(service.pending, contains(40000 + id));

    await db.projectDao.setStatus(id, 1, now);
    await scheduler.reconcile();

    expect(service.pending, isNot(contains(40000 + id)));
  });

  test('clearing a project deadline cancels its reminder', () async {
    final id = await db.projectDao.createProject(
      ProjectsCompanion.insert(
        title: 'Alpha',
        createdAt: now,
        deadline: Value(DateTime(2026, 10, 20)),
      ),
    );
    await scheduler.reconcile();
    expect(service.pending, contains(40000 + id));

    await db.projectDao.updateDeadline(id, null);
    await scheduler.reconcile();

    expect(service.pending, isNot(contains(40000 + id)));
  });

  test('the forced-all-on twin cancels a project reminder when toggled off', () async {
    final id = await db.projectDao.createProject(
      ProjectsCompanion.insert(
        title: 'Alpha',
        createdAt: now,
        deadline: Value(DateTime(2026, 10, 20)),
      ),
    );
    await db.settingsDao.setValue(notifyEventSoonKey, '0');

    // A prior launch scheduled it; this scheduler never saw it.
    service.pending[40000 + id] = (
      at: DateTime(2026, 10, 19, 9),
      title: 'Project deadline tomorrow',
      body: 'x',
    );

    await DriftNotificationScheduler(db, service, now: () => now).reconcile();

    expect(service.pending, isNot(contains(40000 + id)));
  });
}