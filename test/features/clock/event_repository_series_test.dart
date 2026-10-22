import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;

  final created = DateTime(2026, 10, 1, 9);
  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);

  Future<int> addSeries({
    required DateTime validFrom,
    RecurrenceRule? rule,
    String title = 'Standup',
  }) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: created,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => created,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => created),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('watching a day first fills it from its series', () async {
    final seriesId = await addSeries(validFrom: monday);

    final events = await repository.watchDay(tuesday).first;

    expect(events, hasLength(1));
    expect(events.single.title, 'Standup');
    expect(events.single.seriesId, seriesId);
    expect(events.single.date, tuesday);
    expect(events.single.tone, Tone.inbox);
  });

  test('watching the same day again does not duplicate it', () async {
    await addSeries(validFrom: monday);

    await repository.watchDay(tuesday).first;
    final again = await repository.watchDay(tuesday).first;

    expect(again, hasLength(1));
  });

  test('a day before the series starts stays empty', () async {
    await addSeries(validFrom: tuesday);
    expect(await repository.watchDay(monday).first, isEmpty);
  });

  test('without a materialiser nothing is created', () async {
    await addSeries(validFrom: monday);
    final plain = DriftEventRepository(db.eventDao);

    expect(await plain.watchDay(tuesday).first, isEmpty);
  });

  test(
    'a deleted occurrence stays deleted when the day is read again',
    () async {
      await addSeries(validFrom: monday);
      final first = await repository.watchDay(tuesday).first;

      await repository.deleteEvent(first.single.id);

      expect(await repository.watchDay(tuesday).first, isEmpty);
    },
  );

  test('a moved occurrence keeps its series and its new time', () async {
    final seriesId = await addSeries(validFrom: monday);
    final first = await repository.watchDay(tuesday).first;

    await repository.moveEvent(
      id: first.single.id,
      day: tuesday,
      range: const MinuteRange(900, 960),
    );
    final again = await repository.watchDay(tuesday).first;

    expect(again, hasLength(1));
    expect(again.single.range, const MinuteRange(900, 960));
    expect(again.single.seriesId, seriesId);
  });

  test(
    'the week strip dots include days that have only been planned by a series',
    () async {
      await addSeries(validFrom: monday, rule: RecurrenceRule.weekdays());

      final byDay = await repository
          .watchTonesByDay(monday, DateTime(2026, 10, 12))
          .first;

      expect(byDay.keys.map((day) => day.day).toSet(), {5, 6, 7, 8, 9});
      expect(byDay[monday], {Tone.inbox});
    },
  );

  test(
    'a series occurrence on a full day waits instead of breaking the dial',
    () async {
      for (var i = 0; i < 3; i++) {
        await repository.createEvent(
          day: tuesday,
          title: 'Busy $i',
          tone: Tone.focus,
          range: const MinuteRange(540, 600),
        );
      }
      await addSeries(validFrom: monday);

      final events = await repository.watchDay(tuesday).first;

      expect(events, hasLength(3));
      expect(events.every((event) => event.seriesId == null), isTrue);
    },
  );
}
