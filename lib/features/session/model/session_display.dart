import 'dart:math' as math;

import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/repositories/session_repository.dart';

/// What the session screen shows at one moment. Pure data worked out from the
/// session and the time; the screen decides how to draw it.
class SessionDisplay {
  SessionDisplay._({
    required this.isPaused,
    required this.isOvertime,
    required this.plannedSeconds,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.overtimeSeconds,
    required this.plannedEnd,
  });

  factory SessionDisplay.of(RunningSession session, DateTime now) {
    final timing = session.timing;
    final remaining = timing.remainingSecondsAt(now);
    return SessionDisplay._(
      isPaused: timing.isPaused,
      isOvertime: timing.isOvertimeAt(now),
      plannedSeconds: timing.plannedSeconds,
      elapsedSeconds: timing.elapsedSecondsAt(now),
      remainingSeconds: math.max(0, remaining),
      overtimeSeconds: timing.overtimeSecondsAt(now),
      plannedEnd: timing.plannedEnd,
    );
  }

  final bool isPaused;

  /// The planned time is used up. Stays true while paused in overtime.
  final bool isOvertime;

  final int plannedSeconds;
  final int elapsedSeconds;

  /// Seconds left; zero in overtime.
  final int remainingSeconds;

  /// Seconds past the planned end; zero before it.
  final int overtimeSeconds;

  /// When the planned time runs out if the session keeps running.
  final DateTime plannedEnd;

  /// How much of the planned time is left, 1 to 0. Drives the ring.
  double get fractionRemaining =>
      plannedSeconds <= 0 ? 0 : (remainingSeconds / plannedSeconds).clamp(0, 1);

  /// The big number: time left, or "+" and the time over once in overtime.
  String get timeText => isOvertime
      ? '+${formatCountdown(overtimeSeconds)}'
      : formatCountdown(remainingSeconds);

  /// The time as a screen reader should say it.
  String get spokenTime => isOvertime
      ? '${spokenDurationSeconds(overtimeSeconds)} over'
      : '${spokenDurationSeconds(remainingSeconds)} left';

  /// The planned length in the dial's usual short form, "1h 30m".
  String get plannedText =>
      formatDurationMinutes((plannedSeconds / 60).round());
}
