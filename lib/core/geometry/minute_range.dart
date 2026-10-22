import 'dart:math' as math;

import 'package:energy_clock/core/time/day_time.dart';

/// A half-open span of minutes within a single day: [start, end).
class MinuteRange {
  const MinuteRange(this.start, this.end);

  final int start;
  final int end;

  int get durationMinutes => end - start;

  /// True when the two ranges share at least one interior minute. Ranges that
  /// merely touch — one ending exactly where the next begins — do not overlap.
  bool overlaps(MinuteRange other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) =>
      other is MinuteRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MinuteRange($start, $end)';
}

/// Rounds to the nearest snap step and clamps into the day.
int snapMinute(int minute) {
  final snapped = (minute / snapStepMinutes).round() * snapStepMinutes;
  return snapped.clamp(0, minutesPerDay);
}

/// Lifts a wrapped 0–1439 sample onto the continuous minute line closest to
/// [previousContinuous], so a gesture crossing the top of the dial reads as a
/// small step rather than a jump of nearly a full day.
double unwrapMinute(double previousContinuous, int wrappedMinute) {
  var best = wrappedMinute.toDouble();
  var bestDistance = (best - previousContinuous).abs();
  for (final shift in const [-minutesPerDay, minutesPerDay]) {
    final candidate = wrappedMinute + shift.toDouble();
    final distance = (candidate - previousContinuous).abs();
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/// Builds a valid event range from a drag. Snaps both ends, orders them so a
/// backwards drag still produces a forward range, enforces the minimum
/// duration, and clamps at the end of the day — cross-midnight events are not
/// allowed.
MinuteRange rangeFromDrag({
  required int anchorMinute,
  required double currentMinute,
}) {
  final anchor = snapMinute(anchorMinute);
  final current = snapMinute(currentMinute.round());

  var start = math.min(anchor, current);
  var end = math.max(anchor, current);

  if (end - start < minEventMinutes) {
    end = start + minEventMinutes;
  }
  if (end > minutesPerDay) {
    end = minutesPerDay;
    start = math.min(start, minutesPerDay - minEventMinutes);
  }
  return MinuteRange(start, end);
}

/// Builds a default-length event starting at a tap. Snaps the start and slides
/// it back when it would run past the end of the day — cross-midnight events
/// are not allowed.
MinuteRange rangeFromTap({required int minute, int durationMinutes = 60}) {
  var start = snapMinute(minute);
  if (start + durationMinutes > minutesPerDay) {
    start = minutesPerDay - durationMinutes;
  }
  if (start < 0) start = 0;
  return MinuteRange(start, start + durationMinutes);
}

/// Which part of an existing arc a touch grabs.
enum ArcGrabKind { move, resizeStart, resizeEnd }

/// Classifies a touch on an arc. Touches within [edgeMinutes] of either end
/// resize that end; anything else moves the whole event. Events too short to
/// have a distinct middle always move, so a small arc never becomes
/// impossible to drag.
ArcGrabKind grabKindFor({
  required MinuteRange range,
  required int touchMinute,
  int edgeMinutes = 10,
}) {
  if (range.durationMinutes < edgeMinutes * 2) return ArcGrabKind.move;
  if (touchMinute - range.start <= edgeMinutes) return ArcGrabKind.resizeStart;
  if (range.end - touchMinute <= edgeMinutes) return ArcGrabKind.resizeEnd;
  return ArcGrabKind.move;
}

/// Translates a range by [deltaMinutes], clamping inside the day. The
/// duration is preserved — hitting a boundary stops the event rather than
/// squashing it.
MinuteRange moveRange(MinuteRange range, int deltaMinutes) {
  final duration = range.durationMinutes;
  var start = snapMinute(range.start + deltaMinutes);
  if (start + duration > minutesPerDay) start = minutesPerDay - duration;
  if (start < 0) start = 0;
  return MinuteRange(start, start + duration);
}

/// Moves the start edge, keeping at least [minEventMinutes].
MinuteRange resizeRangeStart(MinuteRange range, int newStart) {
  final start = snapMinute(newStart).clamp(0, range.end - minEventMinutes);
  return MinuteRange(start, range.end);
}

/// Moves the end edge, keeping at least [minEventMinutes] and never passing
/// the end of the day.
MinuteRange resizeRangeEnd(MinuteRange range, int newEnd) {
  final end = snapMinute(
    newEnd,
  ).clamp(range.start + minEventMinutes, minutesPerDay);
  return MinuteRange(range.start, end);
}
