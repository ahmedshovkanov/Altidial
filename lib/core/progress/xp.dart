import 'package:altidial/core/progress/streak.dart' show isNextCalendarDay;

/// A timed session pays a point a minute; focus pays half as much again.
int sessionXpMinutes(int minutes, {required bool focus}) =>
    focus ? (minutes * 3 / 2).round() : minutes;

/// Every badge unlock pays 50.
int badgeXp(int unlocks) => unlocks * 50;

/// Long streaks pay 5 XP per day past the first 7 of *each* run. Runs are
/// maximal consecutive-day runs over the sorted unique input.
int streakXp(List<DateTime> allQualifying) {
  final days = {
    for (final day in allQualifying) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  var xp = 0;
  var run = 0;
  for (var i = 0; i < days.length; i++) {
    if (i > 0 && isNextCalendarDay(days[i - 1], days[i])) {
      run++;
    } else {
      run = 1;
    }
    if (run > 7) xp += 5;
  }
  return xp;
}

/// The cumulative XP a level starts at: 100 times the triangular number, so
/// level 1 starts at 0, level 2 at 100, level 3 at 300, level 4 at 600.
int xpToReachLevel(int level) => 100 * (level - 1) * level ~/ 2;

/// The level [xp] has reached: the largest level it can afford, at least 1.
int levelForXp(int xp) {
  var level = 1;
  while (xpToReachLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// Where [xp] sits inside its level, for the progress bar.
({int current, int start, int end}) xpIntoLevel(int xp) {
  final level = levelForXp(xp);
  return (
    current: xp,
    start: xpToReachLevel(level),
    end: xpToReachLevel(level + 1),
  );
}

/// The XP the next level starts at.
int xpForNextLevel(int level) => xpToReachLevel(level + 1);
