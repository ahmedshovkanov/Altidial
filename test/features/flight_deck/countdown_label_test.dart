import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/clock/data/event_repository.dart'
    show CalendarEvent, EventStatus;
import 'package:altidial/features/flight_deck/widgets/next_flight_hero.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent flightAt(DateTime day, int start) => CalendarEvent(
  id: start,
  seriesId: null,
  date: DateTime(day.year, day.month, day.day),
  title: 'LH715',
  tone: Tone.inbox,
  range: MinuteRange(start, start + 120),
  status: EventStatus.planned,
  isFlight: true,
  flightNumber: 'LH715',
  fromCode: 'SOF',
  toCode: 'BER',
);

void main() {
  test('same-day flight uses today label', () {
    final now = DateTime(2026, 10, 14, 8, 0);
    final flight = flightAt(DateTime(2026, 10, 14), 600);
    expect(
      deckCountdownLabel(now, flight),
      Strings.deckCountdownToday(formatMinuteOfDay(600)),
    );
  });

  test('next-day flight uses tomorrow label', () {
    final now = DateTime(2026, 10, 14, 10, 0);
    final flight = flightAt(DateTime(2026, 10, 15), 540);
    expect(
      deckCountdownLabel(now, flight),
      Strings.deckCountdownTomorrow(formatMinuteOfDay(540)),
    );
  });

  test('flight five days out uses in-days label', () {
    final now = DateTime(2026, 10, 14, 10, 0);
    final flight = flightAt(DateTime(2026, 10, 19), 600);
    expect(deckCountdownLabel(now, flight), Strings.deckCountdownDays(5));
    expect(deckCountdownLabel(now, flight), 'In 5 days');
  });
}
