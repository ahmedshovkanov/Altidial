/// The focus target every score measures against, in minutes (spec §9.3). It
/// lives here — not in `lib/app/settings/` — so `lib/core/` never imports
/// `lib/app/`. The settings provider imports this constant as its default.
const int defaultDailyFocusTargetMinutes = 180;

/// One day's minute pool: completed minutes by tone, plus the planned and
/// completed totals.
typedef DayMinutes = ({
  int focus,
  int life,
  int inbox,
  int planned,
  int completed,
});

/// A day's score split into its three parts (spec §9.3).
typedef ScoreBreakdown = ({
  int adherencePoints,
  int focusPoints,
  int balancePoints,
});

/// The total of a breakdown.
extension ScoreTotal on ScoreBreakdown {
  int get total => adherencePoints + focusPoints + balancePoints;
}

/// Scores one day, 0–100. A day with nothing planned and nothing done scores 0
/// outright; any other day earns up to 50 adherence (an unplanned day with
/// sessions still earns the full 50), up to 30 focus against
/// [focusTargetMinutes], and 20/8/0 balance for three/two/one tones used.
ScoreBreakdown scoreFor({
  required DayMinutes day,
  required int focusTargetMinutes,
}) {
  if (day.planned == 0 &&
      day.completed == 0 &&
      day.focus == 0 &&
      day.life == 0 &&
      day.inbox == 0) {
    return (adherencePoints: 0, focusPoints: 0, balancePoints: 0);
  }
  final adherence = day.planned == 0
      ? 50
      : (day.completed * 50 / day.planned).clamp(0, 50).round();
  final target = focusTargetMinutes <= 0
      ? defaultDailyFocusTargetMinutes
      : focusTargetMinutes;
  final focus = (day.focus * 30 / target).clamp(0, 30).round();
  final tonesUsed = [
    day.focus,
    day.life,
    day.inbox,
  ].where((minutes) => minutes > 0).length;
  final balance = switch (tonesUsed) {
    3 => 20,
    2 => 8,
    _ => 0,
  };
  return (
    adherencePoints: adherence,
    focusPoints: focus,
    balancePoints: balance,
  );
}
