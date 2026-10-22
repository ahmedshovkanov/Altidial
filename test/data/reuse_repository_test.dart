import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReuseRepository repository;
  late DateTime now;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  Future<int> addEvent(
    DateTime day, {
    String title = 'Deep work',
    int tone = 0,
    int start = 540,
    int end = 660,
    int status = 0,
    int? seriesId,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: day,
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<EventRow>> onDay(DateTime day) => db.eventDao.eventsForDay(day);

  setUp(() {
    now = DateTime(2026, 10, 7, 8);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftReuseRepository(db.templateDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('saveTemplate', () {
    test('stores the day as a named template', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );

      final id = await repository.saveTemplate(
        name: '  Office day ',
        day: yesterday,
      );

      final templates = await repository.watchTemplates().first;
      expect(templates, hasLength(1));
      expect(templates.single.id, id);
      expect(templates.single.name, 'Office day');
      expect(templates.single.eventCount, 2);
      expect(templates.single.totalMinutes, 165);
      expect(templates.single.tones, [Tone.focus, Tone.life]);
      final items = templates.single.items;
      expect(items.map((item) => item.title), ['Deep work', 'Lunch walk']);
      expect(items.first.tone, Tone.focus);
      expect(items.first.range, const MinuteRange(540, 660));
    });

    test('leaves out skipped events and keeps the rest', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      await repository.saveTemplate(name: 'Day', day: yesterday);

      final template = (await repository.watchTemplates().first).single;
      expect(template.items.map((item) => item.title), ['Deep work']);
    });

    test('refuses a day with nothing on it', () async {
      await expectLater(
        repository.saveTemplate(name: 'Day', day: yesterday),
        throwsA(isA<EmptyDayException>()),
      );
      expect(await repository.watchTemplates().first, isEmpty);
    });

    test('refuses an empty name', () async {
      await addEvent(yesterday);
      expect(
        () => repository.saveTemplate(name: '   ', day: yesterday),
        throwsArgumentError,
      );
    });

    test('a name that is too long is cut to the limit', () async {
      await addEvent(yesterday);

      await repository.saveTemplate(
        name: 'x' * (maxTemplateNameLength + 20),
        day: yesterday,
      );

      final name = (await repository.watchTemplates().first).single.name;
      expect(name, hasLength(maxTemplateNameLength));
    });
  });

  group('watchTemplates', () {
    test('lists the newest template first, items in start order', () async {
      await addEvent(yesterday, title: 'Late', start: 900, end: 960);
      await addEvent(yesterday, title: 'Early', start: 480, end: 540);
      await repository.saveTemplate(name: 'First', day: yesterday);
      now = now.add(const Duration(minutes: 5));
      await repository.saveTemplate(name: 'Second', day: yesterday);

      final templates = await repository.watchTemplates().first;

      expect(templates.map((template) => template.name), ['Second', 'First']);
      expect(templates.first.items.map((item) => item.title), [
        'Early',
        'Late',
      ]);
    });

    test('emits again when a template is saved or deleted', () async {
      await addEvent(yesterday);
      final counts = <int>[];
      final subscription = repository.watchTemplates().listen(
        (templates) => counts.add(templates.length),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await pumpEventQueue();
      await repository.deleteTemplate(id);
      await pumpEventQueue();

      expect(counts.first, 0);
      expect(counts, contains(1));
      expect(counts.last, 0);
    });
  });

  test('deleteTemplate removes the template and its items', () async {
    await addEvent(yesterday);
    final id = await repository.saveTemplate(name: 'Day', day: yesterday);

    await repository.deleteTemplate(id);

    expect(await db.select(db.dayTemplates).get(), isEmpty);
    expect(await db.select(db.dayTemplateItems).get(), isEmpty);
  });

  group('applyTemplate', () {
    test('creates the template events on an empty day', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);

      final created = await repository.applyTemplate(
        templateId: id,
        day: DateTime(2026, 10, 7, 15),
      );

      expect(created, 2);
      final events = await onDay(today);
      expect(events.map((row) => row.title), ['Deep work', 'Lunch walk']);
      expect(events.map((row) => row.toneIndex), [0, 1]);
      expect(events.map((row) => row.startMinute), [540, 750]);
      expect(events.map((row) => row.endMinute), [660, 795]);
      expect(events.every((row) => row.seriesId == null), isTrue);
      expect(
        events.every((row) => row.status == EventStatus.planned.dbIndex),
        isTrue,
      );
      expect(events.first.createdAt, now);
    });

    test('refuses a day that already has events and writes nothing', () async {
      await addEvent(yesterday);
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await addEvent(today, title: 'Already here');

      await expectLater(
        repository.applyTemplate(templateId: id, day: today),
        throwsA(isA<DayNotEmptyException>()),
      );

      expect((await onDay(today)).map((row) => row.title), ['Already here']);
    });

    test('a day with only deleted occurrences counts as empty', () async {
      await addEvent(yesterday);
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await addEvent(
        today,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      expect(await repository.applyTemplate(templateId: id, day: today), 1);
    });

    test('a template that is gone creates nothing', () async {
      expect(await repository.applyTemplate(templateId: 99, day: today), 0);
      expect(await onDay(today), isEmpty);
    });

    test('overlapping events apply as they were', () async {
      await addEvent(yesterday, start: 540, end: 660);
      await addEvent(yesterday, title: 'B', start: 600, end: 700);
      await addEvent(yesterday, title: 'C', start: 620, end: 720);
      final id = await repository.saveTemplate(name: 'Busy', day: yesterday);

      expect(await repository.applyTemplate(templateId: id, day: today), 3);
    });
  });

  group('copyDay', () {
    test('copies the events as planned one-offs', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Standup',
        tone: 2,
        start: 700,
        end: 730,
        seriesId: 5,
        status: EventStatus.completed.dbIndex,
      );

      final created = await repository.copyDay(from: yesterday, to: today);

      expect(created, 2);
      final events = await onDay(today);
      expect(events.map((row) => row.title), ['Deep work', 'Standup']);
      expect(events.map((row) => row.toneIndex), [0, 2]);
      expect(events.map((row) => row.startMinute), [540, 700]);
      expect(events.every((row) => row.seriesId == null), isTrue);
      expect(
        events.every((row) => row.status == EventStatus.planned.dbIndex),
        isTrue,
      );
      expect(await onDay(yesterday), hasLength(2));
    });

    test('leaves out skipped events', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      expect(await repository.copyDay(from: yesterday, to: today), 1);
    });

    test('refuses a day that already has events', () async {
      await addEvent(yesterday);
      await addEvent(today, title: 'Already here');

      await expectLater(
        repository.copyDay(from: yesterday, to: today),
        throwsA(isA<DayNotEmptyException>()),
      );

      expect(await onDay(today), hasLength(1));
    });

    test('an empty source day copies nothing', () async {
      expect(await repository.copyDay(from: yesterday, to: today), 0);
      expect(await onDay(today), isEmpty);
    });
  });
}
