import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/models/series_row_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 1, 9);

  Future<int> addSeries({required DateTime validFrom, RecurrenceRule? rule}) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: 2,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: now,
      ),
    );
  }

  Future<int> addEvent(
    DateTime date, {
    int? seriesId,
    int status = 0,
    int start = 540,
  }) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: date,
        title: 'Standup',
        toneIndex: 2,
        startMinute: start,
        endMinute: start + 30,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('a stored series reads back as its rule', () async {
    final id = await addSeries(
      validFrom: DateTime(2026, 10, 5),
      rule: RecurrenceRule.custom({1, 3}, until: DateTime(2026, 12, 31)),
    );

    final row = await db.seriesDao.seriesById(id);
    expect(
      row!.rule,
      RecurrenceRule.custom({1, 3}, until: DateTime(2026, 12, 31)),
    );
    expect(row.validFrom, DateTime(2026, 10, 5));
    expect(await db.seriesDao.seriesById(99), isNull);
  });

  group('seriesCovering', () {
    test('finds series that can have a day in the range', () async {
      final open = await addSeries(validFrom: DateTime(2026, 10, 1));
      final ended = await addSeries(
        validFrom: DateTime(2026, 9, 1),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 9)),
      );
      await addSeries(validFrom: DateTime(2026, 11, 1));

      final covering = await db.seriesDao.seriesCovering(
        DateTime(2026, 10, 10),
        DateTime(2026, 10, 17),
      );
      expect(covering.map((row) => row.id), [open]);

      final early = await db.seriesDao.seriesCovering(
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 10),
      );
      expect(early.map((row) => row.id), [open, ended]);
    });

    test(
      'a series starting on the last day of the range is included',
      () async {
        final id = await addSeries(validFrom: DateTime(2026, 10, 16));
        final covering = await db.seriesDao.seriesCovering(
          DateTime(2026, 10, 10),
          DateTime(2026, 10, 17),
        );
        expect(covering.map((row) => row.id), [id]);
      },
    );
  });

  test('setValidUntil ends a series and null reopens it', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));

    await db.seriesDao.setValidUntil(id, DateTime(2026, 10, 20));
    expect(
      (await db.seriesDao.seriesById(id))!.validUntil,
      DateTime(2026, 10, 20),
    );

    await db.seriesDao.setValidUntil(id, null);
    expect((await db.seriesDao.seriesById(id))!.validUntil, isNull);
  });

  test('deleteSeries removes the row', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));
    await db.seriesDao.deleteSeries(id);
    expect(await db.seriesDao.seriesById(id), isNull);
  });

  test(
    'occurrenceKeys includes skipped rows and leaves one-offs out',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      await addEvent(DateTime(2026, 10, 5), seriesId: id);
      await addEvent(
        DateTime(2026, 10, 6),
        seriesId: id,
        status: EventStatus.skipped.dbIndex,
      );
      await addEvent(DateTime(2026, 10, 7));
      await addEvent(DateTime(2026, 10, 20), seriesId: id);

      final keys = await db.seriesDao.occurrenceKeys(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
      );
      expect(keys, {
        (seriesId: id, date: DateTime(2026, 10, 5)),
        (seriesId: id, date: DateTime(2026, 10, 6)),
      });
    },
  );

  test('liveEventsBetween leaves out skipped rows and other days', () async {
    await addEvent(DateTime(2026, 10, 5));
    await addEvent(DateTime(2026, 10, 5), status: EventStatus.skipped.dbIndex);
    await addEvent(DateTime(2026, 10, 20));

    final rows = await db.seriesDao.liveEventsBetween(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 15),
    );
    expect(rows, hasLength(1));
  });

  test(
    'rewriteEvent changes the fields and can detach from the series',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      final eventId = await addEvent(DateTime(2026, 10, 5), seriesId: id);

      await db.seriesDao.rewriteEvent(
        id: eventId,
        title: 'Planning',
        toneIndex: 0,
        startMinute: 600,
        endMinute: 660,
        seriesId: null,
        updatedAt: DateTime(2026, 10, 5, 8),
      );

      final row = (await db.seriesDao.eventById(eventId))!;
      expect(row.title, 'Planning');
      expect(row.toneIndex, 0);
      expect(row.startMinute, 600);
      expect(row.endMinute, 660);
      expect(row.seriesId, isNull);
      expect(row.updatedAt, DateTime(2026, 10, 5, 8));
    },
  );

  test(
    'deleteOccurrencesFrom removes that day and later, and their sessions',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      final other = await addSeries(validFrom: DateTime(2026, 10, 1));
      final before = await addEvent(DateTime(2026, 10, 4), seriesId: id);
      final onDay = await addEvent(DateTime(2026, 10, 5), seriesId: id);
      await addEvent(DateTime(2026, 10, 6), seriesId: id, status: 2);
      await addEvent(DateTime(2026, 10, 6), seriesId: other);
      await addEvent(DateTime(2026, 10, 5));
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: onDay,
              startedAt: now,
              plannedSeconds: 1800,
            ),
          );

      await db.seriesDao.deleteOccurrencesFrom(id, DateTime(2026, 10, 5));

      final rows = await db.select(db.events).get();
      expect(rows.where((row) => row.seriesId == id).map((row) => row.id), [
        before,
      ]);
      expect(rows.where((row) => row.seriesId == other), hasLength(1));
      expect(rows.where((row) => row.seriesId == null), hasLength(1));
      expect(await db.select(db.sessions).get(), isEmpty);
    },
  );

  test('deleteEventAndSessions removes the row for good', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));
    final occurrence = await addEvent(DateTime(2026, 10, 5), seriesId: id);
    final keep = await addEvent(DateTime(2026, 10, 5), seriesId: id);
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            eventId: occurrence,
            startedAt: now,
            plannedSeconds: 1800,
          ),
        );

    await db.seriesDao.deleteEventAndSessions(occurrence);

    final rows = await db.select(db.events).get();
    expect(rows.map((row) => row.id), [keep]);
    expect(await db.select(db.sessions).get(), isEmpty);
  });
}
