/// `m:ss` from simulated seconds, rounding *up* so 44.2 shows 0:45 — a
/// countdown must never display a state that is not yet true. Negative
/// input clamps to 0:00; callers show "LATE" themselves.
///
/// Also used on the result overlay to format *elapsed*/total time, which
/// is not a countdown — there, the same round-up just means "at least this
/// many seconds," which is still a reasonable convention.
String formatClock(double seconds) {
  final whole = seconds.ceil().clamp(0, 1 << 30);
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
}
