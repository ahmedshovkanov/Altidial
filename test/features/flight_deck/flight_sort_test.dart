// test/features/flight_deck/flight_sort_test.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent, EventStatus;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent flight(int id, DateTime date, int start, int end) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: DateTime(date.year, date.month, date.day),
      title: 'LH$id',
      tone: Tone.inbox,
      range: MinuteRange(start, end),
      status: EventStatus.planned,
      isFlight: true,
      fromCode: 'SOF',
      toCode: 'BER',
    );

void main() {
  test('past flights sort before split; next is the nearest upcoming', () {
    final now = DateTime(2026, 10, 14, 12);
    final flights = [
      flight(1, DateTime(2026, 10, 20), 600, 700),
      flight(2, DateTime(2026, 10, 10), 600, 700),
      flight(3, DateTime(2026, 10, 14), 900, 1000),
    ];
    final split = splitFlights(flights, now);
    expect(split.past.map((f) => f.id), [2]);
    expect(split.upcoming.map((f) => f.id), [3, 1]);
    expect(split.next?.id, 3);
  });

  test('a flight ending exactly now counts as past; empty gives null next', () {
    final now = DateTime(2026, 10, 14, 12);
    final ending = flight(4, DateTime(2026, 10, 14), 600, 720);
    final split = splitFlights([ending], now);
    expect(split.upcoming, isEmpty);
    expect(split.next, isNull);
    expect(splitFlights([], now).next, isNull);
  });
}
