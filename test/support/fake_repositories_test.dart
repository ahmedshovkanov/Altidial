import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clock_harness.dart';

void main() {
  late ClockHarness harness;

  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);
  final wednesday = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  group('FakeSeriesRepository', () {
    test(
      'createRecurring adds an event that belongs to a new series',
      () async {
        final id = await harness.series.createRecurring(
          day: wednesday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(540, 570),
          rule: RecurrenceRule.daily(),
        );

        final event = harness.repository.eventById(id)!;
        expect(event.seriesId, isNotNull);
        expect(harness.series.rules[event.seriesId], RecurrenceRule.daily());
        expect(harness.series.created, hasLength(1));
        expect(harness.series.created.single.title, 'Standup');
      },
    );

    test('createRecurring refuses a fourth ring', () async {
      for (var i = 0; i < 3; i++) {
        await harness.repository.createEvent(
          day: wednesday,
          title: 'Busy',
          tone: Tone.focus,
          range: const MinuteRange(540, 600),
        );
      }
      await expectLater(
        harness.series.createRecurring(
          day: wednesday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(560, 620),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );
    });

    test(
      'updateFromHere rewrites the event and drops the later days',
      () async {
        final seriesId = harness.series.addSeries(RecurrenceRule.daily());
        final first = harness.repository.addOccurrence(
          seriesId: seriesId,
          day: wednesday,
        );
        harness.repository.addOccurrence(
          seriesId: seriesId,
          day: DateTime(2026, 10, 8),
        );
        final earlier = harness.repository.addOccurrence(
          seriesId: seriesId,
          day: tuesday,
        );

        await harness.series.updateFromHere(
          eventId: first,
          title: 'Planning',
          tone: Tone.focus,
          range: const MinuteRange(600, 660),
          rule: RecurrenceRule.weekdays(),
        );

        final event = harness.repository.eventById(first)!;
        expect(event.title, 'Planning');
        expect(event.tone, Tone.focus);
        expect(event.range, const MinuteRange(600, 660));
        expect(event.seriesId, isNot(seriesId));
        expect(harness.series.rules[event.seriesId], RecurrenceRule.weekdays());
        expect(harness.repository.all.map((e) => e.date.day), [7, 6]);
        expect(harness.repository.eventById(earlier)!.seriesId, seriesId);
        expect(harness.series.updated, hasLength(1));
      },
    );

    test('updateFromHere with no repeat makes the event a one-off', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: wednesday,
      );

      await harness.series.updateFromHere(
        eventId: id,
        title: 'Once',
        tone: Tone.life,
        range: const MinuteRange(540, 600),
        rule: const RecurrenceRule.none(),
      );

      expect(harness.repository.eventById(id)!.seriesId, isNull);
    });

    test('deleteFromHere removes this day and later ones', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final earlier = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: tuesday,
      );
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: wednesday,
      );
      harness.repository.addOccurrence(
        seriesId: seriesId,
        day: DateTime(2026, 10, 8),
      );

      await harness.series.deleteFromHere(id);

      expect(harness.repository.all.map((e) => e.id), [earlier]);
      expect(harness.series.deletedFrom, [id]);
    });

    test('ruleFor reads the stored rule', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.weekdays());
      expect(await harness.series.ruleFor(seriesId), RecurrenceRule.weekdays());
      expect(await harness.series.ruleFor(999), isNull);
    });
  });

  group('FakeReuseRepository', () {
    Future<void> addDay(DateTime day) async {
      await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 660),
      );
      await harness.repository.createEvent(
        day: day,
        title: 'Lunch walk',
        tone: Tone.life,
        range: const MinuteRange(750, 795),
      );
    }

    test('saves a day as a template and applies it to an empty day', () async {
      await addDay(monday);

      final id = await harness.reuse.saveTemplate(
        name: ' Office ',
        day: monday,
      );
      final templates = await harness.reuse.watchTemplates().first;
      expect(templates.single.name, 'Office');
      expect(templates.single.eventCount, 2);

      final created = await harness.reuse.applyTemplate(
        templateId: id,
        day: tuesday,
      );
      expect(created, 2);
      expect(
        (await harness.repository.eventsForDay(tuesday)).map((e) => e.title),
        ['Deep work', 'Lunch walk'],
      );
    });

    test('refuses an empty day and a day that is not empty', () async {
      await expectLater(
        harness.reuse.saveTemplate(name: 'Day', day: monday),
        throwsA(isA<EmptyDayException>()),
      );

      await addDay(monday);
      final id = await harness.reuse.saveTemplate(name: 'Day', day: monday);
      await expectLater(
        harness.reuse.applyTemplate(templateId: id, day: monday),
        throwsA(isA<DayNotEmptyException>()),
      );
      await expectLater(
        harness.reuse.copyDay(from: tuesday, to: monday),
        throwsA(isA<DayNotEmptyException>()),
      );
    });

    test('copyDay duplicates a day as planned events', () async {
      await addDay(monday);
      harness.repository.setStatus(
        (await harness.repository.eventsForDay(monday)).first.id,
        EventStatus.completed,
      );

      expect(await harness.reuse.copyDay(from: monday, to: tuesday), 2);

      final copied = await harness.repository.eventsForDay(tuesday);
      expect(copied.map((e) => e.status).toSet(), {EventStatus.planned});
    });

    test('lists the newest template first and deletes by id', () async {
      await addDay(monday);
      final first = await harness.reuse.saveTemplate(name: 'A', day: monday);
      await harness.reuse.saveTemplate(name: 'B', day: monday);

      var templates = await harness.reuse.watchTemplates().first;
      expect(templates.map((t) => t.name), ['B', 'A']);

      await harness.reuse.deleteTemplate(first);
      templates = await harness.reuse.watchTemplates().first;
      expect(templates.map((t) => t.name), ['B']);
    });
  });

  group('FakeCalendarRepository', () {
    test('sums the minutes per tone for the month', () async {
      await harness.repository.createEvent(
        day: monday,
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await harness.repository.createEvent(
        day: monday,
        title: 'B',
        tone: Tone.focus,
        range: const MinuteRange(300, 330),
      );
      await harness.repository.createEvent(
        day: DateTime(2026, 11, 2),
        title: 'Next month',
        tone: Tone.life,
        range: const MinuteRange(60, 120),
      );

      final month = await harness.calendar
          .watchMonth(DateTime(2026, 10, 20))
          .first;

      expect(month, {
        monday: {Tone.focus: 90},
      });
    });

    test('emits again when an event is added', () async {
      final sizes = <int>[];
      final subscription = harness.calendar
          .watchMonth(monday)
          .listen((month) => sizes.add(month.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await harness.repository.createEvent(
        day: monday,
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await pumpEventQueue();

      expect(sizes.first, 0);
      expect(sizes.last, 1);
    });
  });
}
