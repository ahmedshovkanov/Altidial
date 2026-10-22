import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final day = DateTime(2026, 10, 7);
  final now = DateTime(2026, 10, 7, 9);

  Future<int> add({
    int? seriesId,
    int status = 0,
    int start = 540,
    int end = 600,
    int tone = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: day,
        title: 'Event',
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<EventRow>> everyRow() => db.select(db.events).get();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('skipped rows', () {
    test('are left out of the day queries', () async {
      await add();
      await add(status: EventStatus.skipped.dbIndex, start: 700, end: 760);

      expect(await db.eventDao.eventsForDay(day), hasLength(1));
      expect(await db.eventDao.watchDay(day).first, hasLength(1));
    });

    test('are left out of the tone days', () async {
      await add(status: EventStatus.skipped.dbIndex, tone: 2);

      final rows = await db.eventDao
          .watchToneDays(day, DateTime(2026, 10, 8))
          .first;
      expect(rows, isEmpty);
    });

    test('completed events are still shown', () async {
      await add(status: EventStatus.completed.dbIndex);
      expect(await db.eventDao.eventsForDay(day), hasLength(1));
    });
  });

  group('deleteById', () {
    test('removes a one-off event', () async {
      final id = await add();

      await db.eventDao.deleteById(id, now: now);

      expect(await everyRow(), isEmpty);
    });

    test('keeps an occurrence of a series as a skipped row', () async {
      final id = await add(seriesId: 4);

      await db.eventDao.deleteById(id, now: DateTime(2026, 10, 7, 12));

      final rows = await everyRow();
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.seriesId, 4);
      expect(rows.single.status, EventStatus.skipped.dbIndex);
      expect(rows.single.updatedAt, DateTime(2026, 10, 7, 12));
      expect(await db.eventDao.eventsForDay(day), isEmpty);
    });

    test('removes the sessions of either kind of event', () async {
      final oneOff = await add();
      final occurrence = await add(seriesId: 4, start: 700, end: 760);
      for (final eventId in [oneOff, occurrence]) {
        await db
            .into(db.sessions)
            .insert(
              SessionsCompanion.insert(
                eventId: eventId,
                startedAt: now,
                plannedSeconds: 3600,
              ),
            );
      }

      await db.eventDao.deleteById(oneOff, now: now);
      await db.eventDao.deleteById(occurrence, now: now);

      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('deleting an event that is already gone does nothing', () async {
      await db.eventDao.deleteById(99, now: now);
      expect(await everyRow(), isEmpty);
    });
  });
}
