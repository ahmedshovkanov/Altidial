import 'dart:math' as math;

/// The wall-clock arithmetic behind a session (spec §6.2).
///
/// A session stores when it started, how long it has been paused in total, and
/// when the current pause began (null while running). Everything else is worked
/// out from the system clock each time it is asked for, so the timer cannot
/// drift and does not care that iOS suspends the app.
///
/// All values are whole seconds, and the instants are treated as whole seconds
/// too (the database stores them that way), so a tick on a wall-clock second
/// boundary shows exactly the right number.
class SessionTiming {
  const SessionTiming({
    required this.startedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    required this.pauseStartedAt,
  });

  final DateTime startedAt;

  /// The planned length, including any extensions.
  final int plannedSeconds;

  /// Completed pauses, in total. Does not include a pause in progress.
  final int pausedSeconds;

  /// When the current pause began; null while the session is running.
  final DateTime? pauseStartedAt;

  bool get isPaused => pauseStartedAt != null;

  static int _seconds(DateTime instant) =>
      instant.millisecondsSinceEpoch ~/ 1000;

  /// Time spent actually working at [now]: the time since the start, less every
  /// pause. A pause in progress counts only up to its start, so the figure
  /// freezes while paused. Never negative, even if the device clock was moved
  /// back.
  int elapsedSecondsAt(DateTime now) {
    final reference = pauseStartedAt ?? now;
    final gross = _seconds(reference) - _seconds(startedAt);
    return math.max(0, gross - pausedSeconds);
  }

  /// Seconds until the planned end. Zero or negative once the session is in
  /// overtime.
  int remainingSecondsAt(DateTime now) =>
      plannedSeconds - elapsedSecondsAt(now);

  /// Seconds past the planned end; zero before it.
  int overtimeSecondsAt(DateTime now) =>
      math.max(0, elapsedSecondsAt(now) - plannedSeconds);

  /// True from the instant the planned time is used up.
  bool isOvertimeAt(DateTime now) => remainingSecondsAt(now) <= 0;

  /// The instant the planned time runs out, if the session keeps running
  /// without another pause. Only meaningful while running: completed pauses
  /// move it later, but a pause in progress is not included — use
  /// [pausedSecondsTotalAt] with the current time for that.
  DateTime get plannedEnd =>
      startedAt.add(Duration(seconds: plannedSeconds + pausedSeconds));

  /// How long the pause in progress has lasted at [now], in seconds; zero when
  /// running or when the clock moved back.
  int currentPauseSecondsAt(DateTime now) {
    final start = pauseStartedAt;
    if (start == null) return 0;
    return math.max(0, _seconds(now) - _seconds(start));
  }

  /// The paused total once any pause in progress is closed at [now].
  int pausedSecondsTotalAt(DateTime now) =>
      pausedSeconds + currentPauseSecondsAt(now);
}
