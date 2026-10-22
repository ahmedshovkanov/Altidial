import 'package:altidial/core/notifications/schedule.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 7 October 2026, 10:30.
  final now = DateTime(2026, 10, 7, 10, 30);

  ScheduledEvent event(int id, DateTime startsAt) => (
    id: id,
    startsAt: startsAt,
    title: 'Deep work',
    tone: Tone.focus,
  );

  test('an upcoming event gets a reminder ten minutes before', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 12))],
      projects: const [],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, hasLength(1));
    expect(desired.single.id, 10001);
    expect(desired.single.at, DateTime(2026, 10, 7, 11, 50));
    expect(desired.single.title, 'Deep work');
  });

  test('a passed lead instant is never scheduled', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 10, 35))],
      projects: const [],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, isEmpty);
  });

  test('a switched-off type schedules nothing', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 12))],
      projects: const [],
      now: now,
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    // Only the roundup (Sunday) — no event reminder, no mornings.
    expect(desired.map((item) => item.id), [roundupNotificationId]);
  });

  test('empty mornings get reminders, full mornings do not', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 9, 12))],
      projects: const [],
      now: now,
      eventSoon: false,
      roundup: false,
      morning: true,
      morningMinutes: 480,
    );
    final ids = desired.map((item) => item.id).toSet();
    // Today is empty but its 08:00 passed; the 8th is empty; the 9th is full.
    expect(ids, contains(morningReminderId(DateTime(2026, 10, 8))));
    expect(ids, isNot(contains(morningReminderId(DateTime(2026, 10, 7)))));
    expect(ids, isNot(contains(morningReminderId(DateTime(2026, 10, 9)))));
    final eighth = desired.firstWhere(
      (item) => item.id == morningReminderId(DateTime(2026, 10, 8)),
    );
    expect(eighth.at, DateTime(2026, 10, 8, 8));
  });

  test('the roundup lands on Sunday at eight in the evening', () {
    final desired = computeSchedule(
      events: const [],
      projects: const [],
      now: now, // Wednesday
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired.single.at, DateTime(2026, 10, 11, 20));
    expect(desired.single.body, contains('41'));
  });

  test('on Sunday morning the roundup is today, on Sunday night it is next week', () {
    final morning = computeSchedule(
      events: const [],
      projects: const [],
      now: DateTime(2026, 10, 11, 9),
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(morning.single.at, DateTime(2026, 10, 11, 20));

    final night = computeSchedule(
      events: const [],
      projects: const [],
      now: DateTime(2026, 10, 11, 21),
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(night.single.at, DateTime(2026, 10, 18, 20));
  });

  test('event reminders cap at the nearest 32', () {
    final desired = computeSchedule(
      events: [
        for (var i = 0; i < 100; i++)
          event(i, DateTime(2026, 10, 7, 11).add(Duration(minutes: i))),
      ],
      projects: const [],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, hasLength(32));
    expect(desired.last.id, 10000 + 31);
  });

  test('ids are stable per event and per date', () {
    expect(eventReminderId(7), 10007);
    expect(morningReminderId(DateTime(2026, 10, 9)), 20281009);
    expect(projectDeadlineReminderId(7), 40007);
  });

  test('ISO week numbers match the calendar', () {
    expect(isoWeekNumber(DateTime(2026, 10, 11)), 41);
    expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
    expect(isoWeekNumber(DateTime(2025, 12, 29)), 1);
  });

  group('project deadline reminders', () {
    test('fires 09:00 device-local the day before the deadline', () {
      final desired = computeSchedule(
        events: const [],
        projects: [(id: 7, deadline: DateTime(2026, 10, 20))],
        now: now,
        eventSoon: true,
        roundup: false,
        morning: false,
        morningMinutes: 480,
      );
      expect(desired, hasLength(1));
      expect(desired.single.id, 40007);
      expect(desired.single.at, DateTime(2026, 10, 19, 9));
      expect(desired.single.title, Strings.projectDeadlineReminderTitle);
      expect(desired.single.body, Strings.projectDeadlineReminderBody);
    });

    test('is gated by the event-soon toggle', () {
      final desired = computeSchedule(
        events: const [],
        projects: [(id: 7, deadline: DateTime(2026, 10, 20))],
        now: now,
        eventSoon: false,
        roundup: false,
        morning: false,
        morningMinutes: 480,
      );
      expect(desired, isEmpty);
    });

    test('a past or same-day deadline schedules nothing', () {
      final desired = computeSchedule(
        events: const [],
        projects: [
          (id: 1, deadline: DateTime(2026, 10, 6)), // day-before is past
          (id: 2, deadline: DateTime(2026, 10, 7)), // deadline today
          (id: 3, deadline: DateTime(2026, 10, 8)), // day-before 09:00 < now
        ],
        now: now,
        eventSoon: true,
        roundup: false,
        morning: false,
        morningMinutes: 480,
      );
      expect(desired, isEmpty);
    });

    test('caps at the soonest deadlines', () {
      final desired = computeSchedule(
        events: const [],
        projects: [
          for (var i = 0; i < 100; i++)
            (id: i, deadline: DateTime(2026, 10, 8).add(Duration(days: i))),
        ],
        now: now,
        eventSoon: true,
        roundup: false,
        morning: false,
        morningMinutes: 480,
      );
      expect(desired, hasLength(maxProjectReminders));
      // Project 0's day-before (10/7 09:00) is already past, so the soonest
      // kept reminder belongs to project 1; the budget then fills in order.
      expect(desired.first.id, projectDeadlineReminderId(1));
      expect(
        desired.last.id,
        projectDeadlineReminderId(maxProjectReminders),
      );
    });
  });
}
