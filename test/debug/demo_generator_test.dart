import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 15, 30);
  DemoDataset build() => DemoGenerator(now: () => now).generate();

  test('generates 90 days ending today with all areas populated', () {
    final data = build();
    final days = data.events.map((event) => event.date.value).toSet();

    expect(data.rangeStart, DateTime(2026, 7, 25));
    expect(data.rangeEnd, startOfDay(now));
    expect(data.projects, hasLength(5));
    expect(data.events, isNotEmpty);
    expect(data.sessions, isNotEmpty);
    expect(data.tasks.length, greaterThanOrEqualTo(20));
    expect(data.templates, hasLength(2));
    expect(data.templateItems, isNotEmpty);
    expect(data.intents, isNotEmpty);
    expect(data.reviews, isNotEmpty);
    expect(data.badgeUnlocks, isNotEmpty);
    expect(days, contains(startOfDay(now)));
    expect(days, contains(DateTime(2026, 7, 25)));
    expect(data.events.map((event) => event.toneIndex.value).toSet(), {
      0,
      1,
      2,
    });
  });

  test('is deterministic for the same seed and clock', () {
    final a = build();
    final b = build();

    expect(
      a.events.map((event) => event.title.value).toList(),
      b.events.map((event) => event.title.value).toList(),
    );
    expect(
      a.sessions.map((session) => session.activeSeconds.value).toList(),
      b.sessions.map((session) => session.activeSeconds.value).toList(),
    );
    expect(
      a.badgeUnlocks.map((unlock) => unlock.badgeId.value).toList(),
      b.badgeUnlocks.map((unlock) => unlock.badgeId.value).toList(),
    );
  });

  test('past events have sessions and future events do not', () {
    final data = build();
    final eventById = {for (final event in data.events) event.id.value: event};

    for (final session in data.sessions) {
      final event = eventById[session.eventId.value]!;
      expect(
        event.date.value.isAfter(startOfDay(now)),
        isFalse,
        reason: 'session on ${event.date.value}',
      );
      expect(session.endedAt.value!.isBefore(now), isTrue);
    }

    final future = data.events.where(
      (event) => event.date.value.isAfter(startOfDay(now)),
    );
    expect(future, isNotEmpty);
    final futureIds = future.map((event) => event.id.value).toSet();
    expect(
      data.sessions.where(
        (session) => futureIds.contains(session.eventId.value),
      ),
      isEmpty,
    );
  });

  test('session times and outcomes are internally consistent', () {
    final data = build();
    for (final session in data.sessions) {
      final outcome = SessionOutcome.fromDbIndex(session.outcome.value);
      expect(outcome, isNot(SessionOutcome.running));
      expect(session.plannedSeconds.value, greaterThan(0));
      expect(session.activeSeconds.value, greaterThan(0));
      expect(session.endedAt.value!.isAfter(session.startedAt.value), isTrue);
      if (outcome == SessionOutcome.completed) {
        expect(
          session.activeSeconds.value,
          greaterThanOrEqualTo(session.plannedSeconds.value),
        );
      }
      if (outcome == SessionOutcome.finishedEarly) {
        expect(
          session.activeSeconds.value,
          lessThan(session.plannedSeconds.value),
        );
      }
    }
  });

  test('no day needs more than three overlapping rings', () {
    final data = build();
    final byDay = <DateTime, List<(int, int)>>{};
    for (final event in data.events) {
      byDay.putIfAbsent(event.date.value, () => []).add((
        event.startMinute.value,
        event.endMinute.value,
      ));
    }
    for (final ranges in byDay.values) {
      final points = <(int, int)>[];
      for (final range in ranges) {
        points.add((range.$1, 1));
        points.add((range.$2, -1));
      }
      points.sort(
        (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
      );
      var active = 0;
      for (final point in points) {
        active += point.$2;
        expect(active, lessThanOrEqualTo(3));
      }
    }
  });

  test('today has completed and planned events', () {
    final data = build();
    final today = startOfDay(now);
    final todays = data.events
        .where((event) => event.date.value == today)
        .toList();
    expect(todays, isNotEmpty);
    expect(todays.any((event) => event.status.value == 1), isTrue);
    expect(todays.any((event) => event.status.value == 0), isTrue);
  });

  test('tone indexes are valid', () {
    for (final event in build().events) {
      expect(() => Tone.fromDbIndex(event.toneIndex.value), returnsNormally);
    }
  });
}
