import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, int start, int end) => CalendarEvent(
  id: id,
  seriesId: null,
  date: DateTime(2026, 10, 3),
  title: 'Event $id',
  tone: Tone.focus,
  range: MinuteRange(start, end),
  status: EventStatus.planned,
);

void main() {
  test('nothing is active outside every event', () {
    expect(activeEventsAt([event(1, 540, 600)], 500), isEmpty);
    expect(activeEventsAt(const [], 500), isEmpty);
  });

  test('an event is active from its start minute', () {
    expect(activeEventsAt([event(1, 540, 600)], 540).map((e) => e.id), [1]);
  });

  test('an event is not active at its end minute (end is exclusive)', () {
    expect(activeEventsAt([event(1, 540, 600)], 600), isEmpty);
    expect(activeEventsAt([event(1, 540, 600)], 599).map((e) => e.id), [1]);
  });

  test('overlapping events list the latest-started first', () {
    final events = [event(1, 540, 720), event(2, 600, 660), event(3, 630, 700)];
    expect(activeEventsAt(events, 640).map((e) => e.id), [3, 2, 1]);
  });

  test('events that start together go to the higher id first', () {
    final events = [event(1, 600, 700), event(2, 600, 650)];
    expect(activeEventsAt(events, 610).map((e) => e.id), [2, 1]);
  });

  test('does not modify the list it is given', () {
    final events = [event(1, 540, 720), event(2, 600, 660)];
    activeEventsAt(events, 610);
    expect(events.map((e) => e.id), [1, 2]);
  });
}
