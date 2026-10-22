import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// What the Now card says. Pure data; the card decides how to draw it.
sealed class NowStatus {
  const NowStatus();
}

/// An event is running now (today only).
final class NowActive extends NowStatus {
  const NowActive({
    required this.event,
    required this.minutesLeft,
    required this.progress,
    required this.overlappingCount,
  });

  final CalendarEvent event;

  /// Minutes until the event's end minute.
  final int minutesLeft;

  /// How much of the event has passed, 0 to 1.
  final double progress;

  /// How many other events are running at the same moment.
  final int overlappingCount;
}

/// Nothing is running, but a later event is planned today.
final class NowNext extends NowStatus {
  const NowNext({required this.event, required this.minutesUntil});

  final CalendarEvent event;
  final int minutesUntil;
}

/// Nothing is planned: today with no events, or a future day with none.
final class NowFree extends NowStatus {
  const NowFree();
}

/// Today has events and every one has finished.
final class NowDone extends NowStatus {
  const NowDone({required this.eventCount, required this.plannedMinutes});

  final int eventCount;
  final int plannedMinutes;
}

/// A future day with events, or any past day.
final class DaySummary extends NowStatus {
  const DaySummary({
    required this.eventCount,
    required this.plannedMinutes,
    required this.isPast,
  });

  final int eventCount;
  final int plannedMinutes;
  final bool isPast;
}

/// Decides what the Now card shows for [selectedDay] at [now].
///
/// An event's end minute is exclusive, so an event is not active at its end
/// minute. Planned minutes sum every event's duration, so overlapping events
/// count twice: overlap is extra load.
NowStatus computeNowStatus({
  required List<CalendarEvent> events,
  required DateTime selectedDay,
  required DateTime now,
}) {
  final today = startOfDay(now);
  final day = startOfDay(selectedDay);
  final plannedMinutes = events.fold<int>(
    0,
    (sum, event) => sum + event.range.durationMinutes,
  );

  if (day.isBefore(today)) {
    return DaySummary(
      eventCount: events.length,
      plannedMinutes: plannedMinutes,
      isPast: true,
    );
  }
  if (day.isAfter(today)) {
    if (events.isEmpty) return const NowFree();
    return DaySummary(
      eventCount: events.length,
      plannedMinutes: plannedMinutes,
      isPast: false,
    );
  }

  if (events.isEmpty) return const NowFree();

  final minute = minuteOfDay(now);
  final active = activeEventsAt(events, minute);
  if (active.isNotEmpty) {
    final event = active.first;
    final elapsed = minute - event.startMinute;
    return NowActive(
      event: event,
      minutesLeft: event.endMinute - minute,
      progress: elapsed / event.range.durationMinutes,
      overlappingCount: active.length - 1,
    );
  }

  final upcoming =
      [
        for (final event in events)
          if (event.startMinute > minute) event,
      ]..sort((a, b) {
        final byStart = a.startMinute.compareTo(b.startMinute);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
  if (upcoming.isNotEmpty) {
    return NowNext(
      event: upcoming.first,
      minutesUntil: upcoming.first.startMinute - minute,
    );
  }

  return NowDone(eventCount: events.length, plannedMinutes: plannedMinutes);
}
