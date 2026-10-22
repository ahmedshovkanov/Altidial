/// True when [b] is the calendar day after [a]. Calendar arithmetic, not a
/// 24-hour duration: across a DST change two consecutive local midnights are
/// 23 or 25 real hours apart, and `inDays` would misread them.
bool isNextCalendarDay(DateTime a, DateTime b) =>
    b == DateTime(a.year, a.month, a.day + 1);

/// A streak evaluation: the run ending today (or yesterday), the longest run
/// anywhere, and the latest qualifying day.
typedef Streaks = ({int current, int longest, DateTime? lastDate});

/// Evaluates [qualifyingDays] (local midnights with at least one `countsAsDone`
/// session) against [today]. Duplicates, shuffling and future days are
/// tolerated. A run ending yesterday still counts — the user has until tonight.
Streaks streaks(List<DateTime> qualifyingDays, {required DateTime today}) {
  final todayDay = DateTime(today.year, today.month, today.day);
  final days = {
    for (final day in qualifyingDays)
      if (!day.isAfter(today)) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  if (days.isEmpty) return (current: 0, longest: 0, lastDate: null);

  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (isNextCalendarDay(days[i - 1], days[i])) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }

  final last = days.last;
  var current = 0;
  if (last == todayDay || isNextCalendarDay(last, todayDay)) {
    current = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (isNextCalendarDay(days[i - 1], days[i])) {
        current++;
      } else {
        break;
      }
    }
  }
  return (current: current, longest: longest, lastDate: last);
}
