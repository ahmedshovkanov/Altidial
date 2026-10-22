import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CalendarRepository repository;

  final created = DateTime(2026, 10, 1, 9);
  final october = DateTime(2026, 10, 17);

  Future<int> addEvent(
    DateTime day,
    Tone tone,
    int start,
    int end, {
    int status = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: 'Event',
        toneIndex: tone.dbIndex,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCalendarRepository(
      db.eventDao,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => created),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('gives planned minutes per tone for each day of the month', () async {
    await addEvent(DateTime(2026, 10, 5), Tone.focus, 60, 180);
    await addEvent(DateTime(2026, 10, 5), Tone.life, 300, 360);
    await addEvent(DateTime(2026, 10, 5), Tone.focus, 400, 430);
    await addEvent(DateTime(2026, 10, 31), Tone.inbox, 60, 90);

    final month = await repository.watchMonth(october).first;

    expect(month.keys, {DateTime(2026, 10, 5), DateTime(2026, 10, 31)});
    expect(month[DateTime(2026, 10, 5)], {Tone.focus: 150, Tone.life: 60});
    expect(month[DateTime(2026, 10, 31)], {Tone.inbox: 30});
  });

  test('leaves out other months and skipped events', () async {
    await addEvent(DateTime(2026, 9, 30), Tone.focus, 60, 120);
    await addEvent(DateTime(2026, 11, 1), Tone.focus, 60, 120);
    await addEvent(
      DateTime(2026, 10, 5),
      Tone.focus,
      60,
      120,
      status: EventStatus.skipped.dbIndex,
    );

    expect(await repository.watchMonth(october).first, isEmpty);
  });

  test('fills the month from its series before reading it', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: RecurrenceKind.weekdays.dbIndex,
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );

    final month = await repository.watchMonth(october).first;

    // October 2026 has 22 weekdays; each is 30 minutes of Inbox.
    expect(month, hasLength(22));
    expect(month[DateTime(2026, 10, 1)], {Tone.inbox: 30});
    expect(month.containsKey(DateTime(2026, 10, 3)), isFalse);
  });

  test('a future month is filled too', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Review',
        toneIndex: Tone.focus.dbIndex,
        startMinute: 600,
        endMinute: 660,
        recurrenceKind: RecurrenceKind.custom.dbIndex,
        weekdayMask: const Value(1),
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );

    final month = await repository.watchMonth(DateTime(2027, 1, 20)).first;

    // Mondays in January 2027: 4, 11, 18, 25.
    expect(month.keys.map((day) => day.day), [4, 11, 18, 25]);
    expect(month.values.every((minutes) => minutes[Tone.focus] == 60), isTrue);
  });

  test('without a materialiser it only reads what is stored', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: RecurrenceKind.daily.dbIndex,
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );
    final plain = DriftCalendarRepository(db.eventDao);

    expect(await plain.watchMonth(october).first, isEmpty);
  });

  test('emits again when an event is added', () async {
    final sizes = <int>[];
    final subscription = repository
        .watchMonth(october)
        .listen((month) => sizes.add(month.length));
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await addEvent(DateTime(2026, 10, 5), Tone.focus, 60, 120);
    await pumpEventQueue();

    expect(sizes.first, 0);
    expect(sizes.last, 1);
  });
}
