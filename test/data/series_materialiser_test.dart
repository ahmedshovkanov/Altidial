import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/series_materialiser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeriesMaterialiser materialiser;

  final created = DateTime(2026, 10, 1, 9);
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);

  Future<int> addSeries({
    required DateTime validFrom,
    RecurrenceRule? rule,
    String title = 'Standup',
    int tone = 2,
    int start = 540,
    int end = 570,
  }) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: created,
      ),
    );
  }

  Future<int> addEvent(
    DateTime date, {
    int? seriesId,
    int status = 0,
    int start = 540,
    int end = 600,
  }) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: date,
        title: 'Other',
        toneIndex: 0,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  Future<List<EventRow>> rows() => db.select(db.events).get();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    materialiser = SeriesMaterialiser(db.seriesDao, clock: () => created);
  });

  tearDown(() async {
    await db.close();
  });

  test('a daily series becomes one event per day of the range', () async {
    final id = await addSeries(validFrom: monday);

    await materialiser.materialise(monday, nextMonday);

    final events = await rows();
    expect(events, hasLength(7));
    expect(events.every((row) => row.seriesId == id), isTrue);
    expect(events.map((row) => row.date.day).toList()..sort(), [
      5,
      6,
      7,
      8,
      9,
      10,
      11,
    ]);
  });

  test('the events carry the series fields and start planned', () async {
    await addSeries(
      validFrom: monday,
      title: 'Deep work',
      tone: 0,
      start: 600,
      end: 720,
    );

    await materialiser.materialiseDay(monday);

    final event = (await rows()).single;
    expect(event.title, 'Deep work');
    expect(event.toneIndex, 0);
    expect(event.startMinute, 600);
    expect(event.endMinute, 720);
    expect(event.status, EventStatus.planned.dbIndex);
    expect(event.date, monday);
    expect(event.createdAt, created);
    expect(event.updatedAt, created);
  });

  test('running it again changes nothing', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, nextMonday);
    await materialiser.materialise(monday, nextMonday);
    await materialiser.materialiseDay(DateTime(2026, 10, 7));

    expect(await rows(), hasLength(7));
  });

  test('a weekdays series skips the weekend', () async {
    await addSeries(validFrom: monday, rule: RecurrenceRule.weekdays());

    await materialiser.materialise(monday, nextMonday);

    expect((await rows()).map((row) => row.date.weekday).toSet(), {
      1,
      2,
      3,
      4,
      5,
    });
  });

  test('a custom series gives only its days', () async {
    await addSeries(
      validFrom: monday,
      rule: RecurrenceRule.custom({DateTime.tuesday, DateTime.thursday}),
    );

    await materialiser.materialise(monday, nextMonday);

    expect((await rows()).map((row) => row.date.day).toList()..sort(), [6, 8]);
  });

  test(
    'nothing is created before the series starts or after it ends',
    () async {
      await addSeries(
        validFrom: DateTime(2026, 10, 7),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 9)),
      );

      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day).toList()..sort(), [
        7,
        8,
        9,
      ]);
    },
  );

  test('a deleted occurrence stays deleted', () async {
    final id = await addSeries(validFrom: monday);
    await materialiser.materialise(monday, nextMonday);
    final tuesday = (await rows()).firstWhere((row) => row.date.day == 6);

    await db.eventDao.deleteById(tuesday.id, now: created);
    await materialiser.materialise(monday, nextMonday);

    final events = await rows();
    expect(events, hasLength(7));
    expect(
      events.singleWhere((row) => row.date.day == 6).status,
      EventStatus.skipped.dbIndex,
    );
    expect(await db.eventDao.eventsForDay(DateTime(2026, 10, 6)), isEmpty);
    expect(events.every((row) => row.seriesId == id), isTrue);
  });

  test('an occurrence the person changed is left alone', () async {
    await addSeries(validFrom: monday);
    await materialiser.materialiseDay(monday);
    final event = (await rows()).single;
    await db.eventDao.updateTimes(
      id: event.id,
      startMinute: 900,
      endMinute: 960,
      updatedAt: created,
    );

    await materialiser.materialiseDay(monday);

    final events = await rows();
    expect(events, hasLength(1));
    expect(events.single.startMinute, 900);
  });

  test('a completed occurrence is not duplicated', () async {
    await addSeries(validFrom: monday);
    await materialiser.materialiseDay(monday);
    final event = (await rows()).single;
    await db.sessionDao.setEventStatus(
      eventId: event.id,
      status: EventStatus.completed.dbIndex,
      updatedAt: created,
    );

    await materialiser.materialiseDay(monday);

    expect(await rows(), hasLength(1));
  });

  test('two series on one day each get their event', () async {
    await addSeries(validFrom: monday, title: 'A', start: 540, end: 570);
    await addSeries(validFrom: monday, title: 'B', start: 600, end: 660);

    await materialiser.materialiseDay(monday);

    expect((await rows()).map((row) => row.title).toSet(), {'A', 'B'});
  });

  test('an occurrence that would need a fourth ring waits for room', () async {
    for (var i = 0; i < 3; i++) {
      await addEvent(monday);
    }
    await addSeries(validFrom: monday, start: 560, end: 620);

    await materialiser.materialise(monday, DateTime(2026, 10, 7));

    final onMonday = (await rows()).where((row) => row.date == monday);
    expect(onMonday, hasLength(3));
    final onTuesday = (await rows()).where((row) => row.date.day == 6);
    expect(onTuesday, hasLength(1));

    // Room appears: the occurrence is created the next time the day is read.
    await db.eventDao.deleteById(onMonday.first.id, now: created);
    await materialiser.materialiseDay(monday);

    expect((await rows()).where((row) => row.date == monday), hasLength(3));
    expect(
      (await db.eventDao.eventsForDay(
        monday,
      )).where((row) => row.seriesId != null),
      hasLength(1),
    );
  });

  test('an occurrence is never put in over the ring limit', () async {
    // Four series at the same time would need four rings. Only the three
    // oldest are created.
    await addSeries(validFrom: monday, title: 'A');
    await addSeries(validFrom: monday, title: 'B');
    await addSeries(validFrom: monday, title: 'C');
    await addSeries(validFrom: monday, title: 'D');

    await materialiser.materialiseDay(monday);

    expect(await rows(), hasLength(3));
  });

  test('past days are filled like any other', () async {
    await addSeries(validFrom: DateTime(2026, 9, 1));

    await materialiser.materialise(
      DateTime(2026, 9, 28),
      DateTime(2026, 10, 1),
    );

    expect(await rows(), hasLength(3));
  });

  test('an empty or backwards range does nothing', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, monday);
    await materialiser.materialise(nextMonday, monday);

    expect(await rows(), isEmpty);
  });

  test('a range with no series does nothing', () async {
    await materialiser.materialise(monday, nextMonday);
    expect(await rows(), isEmpty);
  });

  test('days outside the range are not touched', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, DateTime(2026, 10, 7));

    expect((await rows()).map((row) => row.date.day).toList()..sort(), [5, 6]);
  });

  test('a series stored with no repeat creates nothing', () async {
    await addSeries(validFrom: monday, rule: const RecurrenceRule.none());

    await materialiser.materialise(monday, nextMonday);

    expect(await rows(), isEmpty);
  });
}
