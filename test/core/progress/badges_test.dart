import 'package:altidial/core/progress/badges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const empty = BadgeFacts(
    endedSessions: 0,
    qualifyingDates: [],
    fourHourFocusDays: {},
    allToneWeeks: {},
    cleanWeeks: {},
    hasEarlyFocus: false,
  );

  BadgeFacts withSessions(int count) => BadgeFacts(
    endedSessions: count,
    qualifyingDates: const [],
    fourHourFocusDays: const {},
    allToneWeeks: const {},
    cleanWeeks: const {},
    hasEarlyFocus: false,
  );

  test('the definitions are ten stable ids in spec order', () {
    expect(badgeDefinitions.map((badge) => badge.id), [
      'first_session',
      'sessions_10',
      'sessions_50',
      'sessions_100',
      'focus_day_4h',
      'week_all_tones',
      'streak_7',
      'streak_30',
      'week_no_abandoned',
      'early_bird',
    ]);
    for (final badge in badgeDefinitions) {
      expect(badge.title, isNotEmpty);
      expect(badge.description, isNotEmpty);
    }
  });

  test('empty facts earn nothing', () {
    expect(badgesToUnlock(empty, const {}), isEmpty);
  });

  test('session counts unlock their badges together', () {
    expect(badgesToUnlock(withSessions(1), const {}), ['first_session']);
    expect(badgesToUnlock(withSessions(100), const {}), [
      'first_session',
      'sessions_10',
      'sessions_50',
      'sessions_100',
    ]);
  });

  test('already-unlocked badges are not awarded again', () {
    expect(
      badgesToUnlock(withSessions(100), {'first_session', 'sessions_10'}),
      ['sessions_50', 'sessions_100'],
    );
  });

  test('day, week and early badges read their own facts', () {
    final facts = BadgeFacts(
      endedSessions: 5,
      qualifyingDates: const [],
      fourHourFocusDays: {DateTime(2026, 10, 6)},
      allToneWeeks: {DateTime(2026, 10, 5)},
      cleanWeeks: {DateTime(2026, 10, 5)},
      hasEarlyFocus: true,
    );
    expect(badgesToUnlock(facts, const {}), [
      'first_session',
      'focus_day_4h',
      'week_all_tones',
      'week_no_abandoned',
      'early_bird',
    ]);
  });

  test('streak badges need a long enough run', () {
    BadgeFacts run(int days) => BadgeFacts(
      endedSessions: days,
      qualifyingDates: [for (var d = 1; d <= days; d++) DateTime(2026, 9, d)],
      fourHourFocusDays: const {},
      allToneWeeks: const {},
      cleanWeeks: const {},
      hasEarlyFocus: false,
    );
    expect(badgesToUnlock(run(7), const {}), contains('streak_7'));
    expect(badgesToUnlock(run(7), const {}), isNot(contains('streak_30')));
    expect(
      badgesToUnlock(run(30), const {}),
      containsAll(['streak_7', 'streak_30']),
    );
  });

  test('longestRun tolerates shuffling and duplicates', () {
    expect(longestRun(const []), 0);
    expect(
      longestRun([
        DateTime(2026, 10, 7),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 6),
      ]),
      3,
    );
  });
}
