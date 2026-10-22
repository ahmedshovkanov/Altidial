import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// The events running at [minute] (`start <= minute < end`), latest-started
/// first; events that start together go to the higher id first. The first one
/// is the event shown as "now" everywhere, so the dial and the Now card always
/// agree. Does not modify [events].
List<CalendarEvent> activeEventsAt(List<CalendarEvent> events, int minute) {
  final active = [
    for (final event in events)
      if (minute >= event.startMinute && minute < event.endMinute) event,
  ];
  active.sort((a, b) {
    final byStart = b.startMinute.compareTo(a.startMinute);
    return byStart != 0 ? byStart : b.id.compareTo(a.id);
  });
  return active;
}
