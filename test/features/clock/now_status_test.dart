import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/model/now_status.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime today = DateTime(2026, 10, 7);

DateTime at(int hour, int minute) => DateTime(2026, 10, 7, hour, minute);

CalendarEvent event(int id, int start, int end, {Tone tone = Tone.focus}) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: today,
      title: 'Event $id',
      tone: tone,
      range: MinuteRange(start, end),
      status: EventStatus.planned,
    );

NowStatus status(List<CalendarEvent> events, {DateTime? day, DateTime? now}) =>
    computeNowStatus(
      events: events,
      selectedDay: day ?? today,
      now: now ?? at(10, 30),
    );

void main() {
  group('today', () {
    test('no events is free', () {
      expect(status(const []), isA<NowFree>());
    });

    test('an event running now is active, with time left and progress', () {
      final result = status([event(1, 540, 720)]); // 09:00-12:00 at 10:30
      expect(result, isA<NowActive>());
      final active = result as NowActive;
      expect(active.event.id, 1);
      expect(active.minutesLeft, 90);
      expect(active.progress, closeTo(0.5, 1e-9));
      expect(active.overlappingCount, 0);
    });

    test('an event is active at its start minute, with no progress yet', () {
      final active = status([event(1, 630, 690)]) as NowActive; // starts 10:30
      expect(active.minutesLeft, 60);
      expect(active.progress, 0);
    });

    test('an event is not active at its end minute', () {
      final result = status([event(1, 540, 630)]); // ends 10:30
      expect(result, isA<NowDone>());
    });

    test('overlapping events show the latest-started with a count', () {
      final active =
          status([event(1, 540, 720), event(2, 600, 660), event(3, 700, 760)])
              as NowActive;
      expect(active.event.id, 2);
      expect(active.overlappingCount, 1);
    });

    test('three overlapping events count two others', () {
      final active =
          status([event(1, 540, 720), event(2, 600, 700), event(3, 620, 680)])
              as NowActive;
      expect(active.event.id, 3);
      expect(active.overlappingCount, 2);
    });

    test('nothing running but something later is next', () {
      final result = status([event(1, 540, 600), event(2, 750, 810)]);
      expect(result, isA<NowNext>());
      final next = result as NowNext;
      expect(next.event.id, 2);
      expect(next.minutesUntil, 120);
    });

    test('next is the earliest upcoming event', () {
      final next =
          status([event(2, 900, 960), event(1, 750, 810), event(3, 780, 800)])
              as NowNext;
      expect(next.event.id, 1);
    });

    test('events that start together: the lower id is next', () {
      final next = status([event(2, 750, 810), event(1, 750, 800)]) as NowNext;
      expect(next.event.id, 1);
    });

    test(
      'everything finished is done, with a count and the planned minutes',
      () {
        final result = status([event(1, 540, 600), event(2, 600, 630)]);
        expect(result, isA<NowDone>());
        final done = result as NowDone;
        expect(done.eventCount, 2);
        expect(done.plannedMinutes, 90);
      },
    );

    test('planned minutes count overlapping events twice', () {
      final done =
          status([event(1, 60, 120), event(2, 60, 120)], now: at(20, 0))
              as NowDone;
      expect(done.plannedMinutes, 120);
    });

    test('the time of day on the selected day is ignored', () {
      final result = status([
        event(1, 540, 720),
      ], day: DateTime(2026, 10, 7, 23, 59));
      expect(result, isA<NowActive>());
    });
  });

  group('other days', () {
    test('a future day with events is a summary', () {
      final result = status([
        event(1, 540, 720),
        event(2, 780, 840),
      ], day: DateTime(2026, 10, 8));
      expect(result, isA<DaySummary>());
      final summary = result as DaySummary;
      expect(summary.eventCount, 2);
      expect(summary.plannedMinutes, 240);
      expect(summary.isPast, isFalse);
    });

    test('an empty future day is free', () {
      expect(status(const [], day: DateTime(2026, 10, 8)), isA<NowFree>());
    });

    test('a future day never shows an active event, whatever the time', () {
      final result = status([event(1, 540, 720)], day: DateTime(2026, 10, 8));
      expect(result, isA<DaySummary>());
    });

    test('a past day with events is a past summary', () {
      final summary =
          status([event(1, 540, 720)], day: DateTime(2026, 10, 6))
              as DaySummary;
      expect(summary.isPast, isTrue);
      expect(summary.eventCount, 1);
      expect(summary.plannedMinutes, 180);
    });

    test('an empty past day is a past summary with nothing in it', () {
      final summary =
          status(const [], day: DateTime(2026, 10, 6)) as DaySummary;
      expect(summary.isPast, isTrue);
      expect(summary.eventCount, 0);
    });
  });
}
