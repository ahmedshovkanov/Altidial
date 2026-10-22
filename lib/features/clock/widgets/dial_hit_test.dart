import 'dart:ui';

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// The event drawn under [point], or null. Matches on both ring and minute,
/// so overlapping events on different rings are distinguishable.
CalendarEvent? eventAtPoint({
  required Offset point,
  required DialGeometry geometry,
  required List<CalendarEvent> events,
  required Map<int, int> ringByEventId,
}) {
  final ring = geometry.ringAtPoint(point);
  if (ring == null) return null;

  final minute = geometry.minuteAtPoint(point);
  for (final event in events) {
    if (ringByEventId[event.id] != ring) continue;
    if (minute >= event.startMinute && minute < event.endMinute) return event;
  }
  return null;
}
