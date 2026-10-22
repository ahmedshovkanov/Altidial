import 'package:altidial/core/progress/streak.dart' show isNextCalendarDay;
import 'package:altidial/core/strings.dart';

/// Everything the badge predicates read, queried from source tables at
/// evaluation time (spec §9.1) — never from the `day_scores` cache. Weeks are
/// Monday starts, always.
class BadgeFacts {
  const BadgeFacts({
    required this.endedSessions,
    required this.qualifyingDates,
    required this.fourHourFocusDays,
    required this.allToneWeeks,
    required this.cleanWeeks,
    required this.hasEarlyFocus,
  });

  /// Every non-running session ever: the denominator of the count badges.
  final int endedSessions;

  /// Sorted unique local midnights with a `countsAsDone` session.
  final List<DateTime> qualifyingDates;

  /// Days with at least 240 `countsAsDone` focus minutes.
  final Set<DateTime> fourHourFocusDays;

  /// Monday starts of weeks with minutes in all three tones.
  final Set<DateTime> allToneWeeks;

  /// Monday starts of weeks with at least one ended session and none abandoned.
  final Set<DateTime> cleanWeeks;

  /// Whether a `countsAsDone` focus session ever started before 08:00.
  final bool hasEarlyFocus;
}

/// One badge: a stable id, its copy, and its predicate over the facts.
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.test,
  });

  final String id;
  final String title;
  final String description;
  final bool Function(BadgeFacts facts) test;
}

/// The longest maximal consecutive-day run in [days]. Order- and
/// duplicate-tolerant.
int longestRun(List<DateTime> days) {
  final sorted = {
    for (final day in days) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  var longest = 0;
  var run = 0;
  for (var i = 0; i < sorted.length; i++) {
    if (i > 0 && isNextCalendarDay(sorted[i - 1], sorted[i])) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }
  return longest;
}

/// The ten badges, in spec §9.4 order.
final List<BadgeDefinition> badgeDefinitions = [
  BadgeDefinition(
    id: 'first_session',
    title: Strings.badgeFirstSessionTitle,
    description: Strings.badgeFirstSessionDescription,
    test: (facts) => facts.endedSessions >= 1,
  ),
  BadgeDefinition(
    id: 'sessions_10',
    title: Strings.badgeSessions10Title,
    description: Strings.badgeSessions10Description,
    test: (facts) => facts.endedSessions >= 10,
  ),
  BadgeDefinition(
    id: 'sessions_50',
    title: Strings.badgeSessions50Title,
    description: Strings.badgeSessions50Description,
    test: (facts) => facts.endedSessions >= 50,
  ),
  BadgeDefinition(
    id: 'sessions_100',
    title: Strings.badgeSessions100Title,
    description: Strings.badgeSessions100Description,
    test: (facts) => facts.endedSessions >= 100,
  ),
  BadgeDefinition(
    id: 'focus_day_4h',
    title: Strings.badgeFocusDayTitle,
    description: Strings.badgeFocusDayDescription,
    test: (facts) => facts.fourHourFocusDays.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'week_all_tones',
    title: Strings.badgeWeekTonesTitle,
    description: Strings.badgeWeekTonesDescription,
    test: (facts) => facts.allToneWeeks.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'streak_7',
    title: Strings.badgeStreak7Title,
    description: Strings.badgeStreak7Description,
    test: (facts) => longestRun(facts.qualifyingDates) >= 7,
  ),
  BadgeDefinition(
    id: 'streak_30',
    title: Strings.badgeStreak30Title,
    description: Strings.badgeStreak30Description,
    test: (facts) => longestRun(facts.qualifyingDates) >= 30,
  ),
  BadgeDefinition(
    id: 'week_no_abandoned',
    title: Strings.badgeCleanWeekTitle,
    description: Strings.badgeCleanWeekDescription,
    test: (facts) => facts.cleanWeeks.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'early_bird',
    title: Strings.badgeEarlyBirdTitle,
    description: Strings.badgeEarlyBirdDescription,
    test: (facts) => facts.hasEarlyFocus,
  ),
];

/// The ids in [badgeDefinitions] order that [facts] newly earn: predicates
/// that hold, minus [alreadyUnlocked].
List<String> badgesToUnlock(BadgeFacts facts, Set<String> alreadyUnlocked) => [
  for (final badge in badgeDefinitions)
    if (!alreadyUnlocked.contains(badge.id) && badge.test(facts)) badge.id,
];
