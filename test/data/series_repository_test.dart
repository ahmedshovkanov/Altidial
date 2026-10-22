import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/geometry/ring_layout.dart';
import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/models/series_row_rule.dart';
import 'package:altidial/data/repositories/series_materialiser.dart';
import 'package:altidial/data/repositories/series_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeriesRepository repository;
  late SeriesMaterialiser materialiser;

  final now = DateTime(2026, 10, 5, 8);
  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);
  final wednesday = DateTime(2026, 10, 7);
  final friday = DateTime(2026, 10, 9);
  final nextMonday = DateTime(2026, 10, 12);

  Future<List<EventRow>> rows() async {
    final all = await db.select(db.events).get();
    all.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return all;
  }

  Future<EventRow> rowOn(DateTime day) async =>
      (await rows()).singleWhere((row) => row.date == day);

  Future<int> createDailyWeek() async {
    final eventId = await repository.createRecurring(
      day: monday,
      title: 'Standup',
      tone: Tone.inbox,
      range: const MinuteRange(540, 570),
      rule: RecurrenceRule.daily(),
    );
    await materialiser.materialise(monday, nextMonday);
    return (await db.seriesDao.eventById(eventId))!.seriesId!;
  }

  Future<int> addOneOff(DateTime day, int start, int end) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: 'One-off',
        toneIndex: 0,
        startMinute: start,
        endMinute: end,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSeriesRepository(db.seriesDao, clock: () => now);
    materialiser = SeriesMaterialiser(db.seriesDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  test('a series that is gone reads as no rule', () async {
    expect(await repository.ruleFor(99), isNull);
  });

  group('createRecurring', () {
    test('writes the series and its first event', () async {
      final eventId = await repository.createRecurring(
        day: DateTime(2026, 10, 5, 17, 30),
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.weekdays(),
      );

      final events = await rows();
      expect(events, hasLength(1));
      expect(events.single.id, eventId);
      expect(events.single.date, monday);
      expect(events.single.status, EventStatus.planned.dbIndex);

      final series = (await db.seriesDao.seriesById(events.single.seriesId!))!;
      expect(series.title, 'Standup');
      expect(series.toneIndex, Tone.inbox.dbIndex);
      expect(series.startMinute, 540);
      expect(series.endMinute, 570);
      expect(series.rule, RecurrenceRule.weekdays());
      expect(series.validFrom, monday);
      expect(series.createdAt, now);
    });

    test('the rest of the series appears when its days are filled', () async {
      final seriesId = await createDailyWeek();

      final events = await rows();
      expect(events, hasLength(7));
      expect(events.every((row) => row.seriesId == seriesId), isTrue);
    });

    test(
      'the first event exists even if its weekday is not in the rule',
      () async {
        await repository.createRecurring(
          day: monday,
          title: 'Gym',
          tone: Tone.life,
          range: const MinuteRange(1020, 1080),
          rule: RecurrenceRule.custom({DateTime.tuesday}),
        );
        await materialiser.materialise(monday, nextMonday);

        expect((await rows()).map((row) => row.date.day), [5, 6]);
      },
    );

    test('keeps the end day of the rule', () async {
      final eventId = await repository.createRecurring(
        day: monday,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 20)),
      );

      final seriesId = (await db.seriesDao.eventById(eventId))!.seriesId!;
      expect(
        (await db.seriesDao.seriesById(seriesId))!.validUntil,
        DateTime(2026, 10, 20),
      );
    });

    test('an end day before the first day is moved up to it', () async {
      final eventId = await repository.createRecurring(
        day: monday,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 1)),
      );

      final seriesId = (await db.seriesDao.eventById(eventId))!.seriesId!;
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, monday);
    });

    test('refuses a fourth ring and writes nothing', () async {
      for (var i = 0; i < 3; i++) {
        await addOneOff(monday, 540, 600);
      }

      await expectLater(
        repository.createRecurring(
          day: monday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(560, 620),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );

      expect(await rows(), hasLength(3));
      expect(await db.select(db.eventSeries).get(), isEmpty);
    });
  });

  test(
    'ruleFor returns the stored rule, and null for a missing series',
    () async {
      final seriesId = await createDailyWeek();

      expect(await repository.ruleFor(seriesId), RecurrenceRule.daily());
      expect(await repository.ruleFor(999), isNull);
    },
  );

  group('updateFromHere', () {
    test('splits the series: earlier days keep the old values', () async {
      final oldSeries = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );
      await materialiser.materialise(monday, nextMonday);

      final events = await rows();
      expect(events, hasLength(7));
      for (final row in events.where((row) => row.date.day < 7)) {
        expect(row.title, 'Standup');
        expect(row.seriesId, oldSeries);
      }
      final newSeries = events[2].seriesId!;
      expect(newSeries, isNot(oldSeries));
      for (final row in events.where((row) => row.date.day >= 7)) {
        expect(row.title, 'Planning');
        expect(row.toneIndex, Tone.focus.dbIndex);
        expect(row.startMinute, 600);
        expect(row.endMinute, 660);
        expect(row.seriesId, newSeries);
      }
      expect(events[2].id, onWednesday.id);

      expect((await db.seriesDao.seriesById(oldSeries))!.validUntil, tuesday);
      final created = (await db.seriesDao.seriesById(newSeries))!;
      expect(created.validFrom, wednesday);
      expect(created.title, 'Planning');
    });

    test('a later deleted day comes back under the new series', () async {
      await createDailyWeek();
      await db.eventDao.deleteById((await rowOn(friday)).id, now: now);
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );
      await materialiser.materialise(monday, nextMonday);

      final onFriday = await db.eventDao.eventsForDay(friday);
      expect(onFriday.single.title, 'Planning');
    });

    test(
      'a rule of never keeps this event alone and removes the later ones',
      () async {
        final oldSeries = await createDailyWeek();
        final onWednesday = await rowOn(wednesday);

        await repository.updateFromHere(
          eventId: onWednesday.id,
          title: 'Once',
          tone: Tone.life,
          range: const MinuteRange(700, 760),
          rule: const RecurrenceRule.none(),
        );
        await materialiser.materialise(monday, nextMonday);

        final events = await rows();
        expect(events.map((row) => row.date.day), [5, 6, 7]);
        expect(events.last.title, 'Once');
        expect(events.last.seriesId, isNull);
        expect((await db.seriesDao.seriesById(oldSeries))!.validUntil, tuesday);
      },
    );

    test('editing the first day replaces the series', () async {
      final oldSeries = await createDailyWeek();
      final onMonday = await rowOn(monday);

      await repository.updateFromHere(
        eventId: onMonday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );

      expect(await db.seriesDao.seriesById(oldSeries), isNull);
      final series = await db.select(db.eventSeries).get();
      expect(series, hasLength(1));
      expect(series.single.title, 'Planning');
      expect(series.single.validFrom, monday);
    });

    test('changing the rule changes which days fill', () async {
      await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.weekdays(),
      );
      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day), [5, 6, 7, 8, 9]);
    });

    test('turns a one-off event into a repeating one', () async {
      final eventId = await addOneOff(wednesday, 540, 600);

      await repository.updateFromHere(
        eventId: eventId,
        title: 'Weekly review',
        tone: Tone.focus,
        range: const MinuteRange(540, 600),
        rule: RecurrenceRule.custom({DateTime.wednesday, DateTime.friday}),
      );
      await materialiser.materialise(monday, nextMonday);

      final events = await rows();
      expect(events.map((row) => row.date.day), [7, 9]);
      expect(events.first.id, eventId);
      expect(events.first.title, 'Weekly review');
      expect(events.first.seriesId, isNotNull);
      expect(events.first.seriesId, events.last.seriesId);
    });

    test('refuses a fourth ring and changes nothing', () async {
      final seriesId = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);
      for (var i = 0; i < 3; i++) {
        await addOneOff(wednesday, 600, 700);
      }
      final before = await rows();

      await expectLater(
        repository.updateFromHere(
          eventId: onWednesday.id,
          title: 'Moved',
          tone: Tone.focus,
          range: const MinuteRange(650, 680),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );

      expect(await rows(), before);
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, isNull);
    });

    test('an event that is gone is ignored', () async {
      await repository.updateFromHere(
        eventId: 999,
        title: 'Nothing',
        tone: Tone.life,
        range: const MinuteRange(540, 600),
        rule: RecurrenceRule.daily(),
      );
      expect(await db.select(db.eventSeries).get(), isEmpty);
    });

    test('the sessions of the edited event are kept', () async {
      await createDailyWeek();
      final onWednesday = await rowOn(wednesday);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: onWednesday.id,
              startedAt: now,
              plannedSeconds: 1800,
              outcome: const Value(1),
            ),
          );

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );

      expect(await db.select(db.sessions).get(), hasLength(1));
    });
  });

  group('deleteFromHere', () {
    test('removes this day and later, and ends the series', () async {
      final seriesId = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.deleteFromHere(onWednesday.id);
      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day), [5, 6]);
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, tuesday);
    });

    test('deleting the first day removes the series', () async {
      final seriesId = await createDailyWeek();
      final onMonday = await rowOn(monday);

      await repository.deleteFromHere(onMonday.id);
      await materialiser.materialise(monday, nextMonday);

      expect(await rows(), isEmpty);
      expect(await db.seriesDao.seriesById(seriesId), isNull);
    });

    test('later deleted days go too', () async {
      await createDailyWeek();
      await db.eventDao.deleteById((await rowOn(friday)).id, now: now);

      await repository.deleteFromHere((await rowOn(wednesday)).id);

      expect((await rows()).map((row) => row.date.day), [5, 6]);
    });

    test('removes a one-off event and its sessions', () async {
      final eventId = await addOneOff(wednesday, 540, 600);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: eventId,
              startedAt: now,
              plannedSeconds: 3600,
            ),
          );

      await repository.deleteFromHere(eventId);

      expect(await rows(), isEmpty);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('an event that is gone is ignored', () async {
      await repository.deleteFromHere(999);
      expect(await rows(), isEmpty);
    });
  });
}
