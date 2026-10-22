import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// Planned minutes per tone for one day.
class DayLoad {
  const DayLoad(this.minutesByTone);

  final Map<Tone, int> minutesByTone;

  int minutesFor(Tone tone) => minutesByTone[tone] ?? 0;

  int get totalMinutes =>
      minutesByTone.values.fold<int>(0, (sum, minutes) => sum + minutes);

  bool get isEmpty => totalMinutes == 0;

  /// The tones that have planned time, in the fixed tone order.
  List<Tone> get tones => [
    for (final tone in Tone.values)
      if (minutesFor(tone) > 0) tone,
  ];
}

/// Sums each event's duration per tone. Overlapping events count twice,
/// because overlap is extra load.
DayLoad computeDayLoad(List<CalendarEvent> events) {
  final minutes = <Tone, int>{};
  for (final event in events) {
    minutes[event.tone] =
        (minutes[event.tone] ?? 0) + event.range.durationMinutes;
  }
  return DayLoad(minutes);
}

/// Widths for the segments of the day-load bar. Each segment is proportional
/// to its [minutes], except that any non-zero segment is at least [minWidth] so
/// it stays visible; the others give way so the widths still add up to
/// [available]. A zero-minute segment gets width 0.
List<double> segmentWidths(
  List<int> minutes,
  double available, {
  double minWidth = 8,
}) {
  final widths = List<double>.filled(minutes.length, 0);
  final active = [
    for (var i = 0; i < minutes.length; i++)
      if (minutes[i] > 0) i,
  ];
  if (active.isEmpty || available <= 0) return widths;

  final pinned = <int>{};
  while (true) {
    final free = [
      for (final i in active)
        if (!pinned.contains(i)) i,
    ];
    final remaining = available - pinned.length * minWidth;
    final freeTotal = free.fold<int>(0, (sum, i) => sum + minutes[i]);
    if (free.isEmpty || remaining <= 0 || freeTotal == 0) break;

    final tooSmall = [
      for (final i in free)
        if (remaining * minutes[i] / freeTotal < minWidth) i,
    ];
    if (tooSmall.isEmpty) {
      for (final i in free) {
        widths[i] = remaining * minutes[i] / freeTotal;
      }
      break;
    }
    pinned.addAll(tooSmall);
  }
  for (final i in pinned) {
    widths[i] = minWidth;
  }
  return widths;
}
