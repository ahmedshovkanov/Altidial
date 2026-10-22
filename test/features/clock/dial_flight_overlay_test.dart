import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CalendarEvent flight() => CalendarEvent(
    id: 1,
    seriesId: null,
    date: DateTime(2026, 10, 14),
    title: 'Fly home',
    tone: Tone.inbox,
    range: const MinuteRange(625, 850),
    status: EventStatus.planned,
    isFlight: true,
    flightNumber: 'LH715',
    fromCode: 'SOF',
    toCode: 'BER',
  );

  test('overlay label shows route with plane marker', () {
    expect(flightOverlayLabel(flight()), '✈ SOF→BER');
  });

  test('overlay label falls back to title when route is missing', () {
    final noRoute = CalendarEvent(
      id: 2,
      seriesId: null,
      date: DateTime(2026, 10, 14),
      title: 'Fly home',
      tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      status: EventStatus.planned,
      isFlight: true,
    );
    expect(flightOverlayLabel(noRoute), '✈ Fly home');
  });
}
