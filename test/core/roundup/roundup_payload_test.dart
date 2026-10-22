import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final payload = RoundupPayload(
    isoYear: 2026,
    isoWeek: 40,
    weekStart: DateTime(2026, 9, 28),
    adherencePercent: 83,
    plannedMinutes: 900,
    completedMinutes: 750,
    totalMinutes: 750,
    focusMinutes: 480,
    lifeMinutes: 180,
    inboxMinutes: 90,
    bestFocusDay: DateTime(2026, 10, 1),
    bestFocusMinutes: 240,
    currentStreak: 5,
    longestStreak: 12,
    badgesUnlocked: ['first_session', 'streak_7'],
    xpEarned: 320,
    previousAdherencePercent: 71,
  );

  test('round-trips through JSON, nulls included', () {
    final decoded = RoundupPayload.fromJson(payload.toJson());
    expect(decoded.toJson(), payload.toJson());

    final empty = RoundupPayload(
      isoYear: 2026,
      isoWeek: 41,
      weekStart: DateTime(2026, 10, 5),
      adherencePercent: null,
      plannedMinutes: 0,
      completedMinutes: 0,
      totalMinutes: 0,
      focusMinutes: 0,
      lifeMinutes: 0,
      inboxMinutes: 0,
      bestFocusDay: null,
      bestFocusMinutes: 0,
      currentStreak: 0,
      longestStreak: 0,
      badgesUnlocked: [],
      xpEarned: 0,
      previousAdherencePercent: null,
    );
    expect(RoundupPayload.fromJson(empty.toJson()).toJson(), empty.toJson());
  });

  test('decodes the documented shape', () {
    final decoded = RoundupPayload.fromJson({
      'isoYear': 2026,
      'isoWeek': 40,
      'weekStart': '2026-09-28',
      'adherencePercent': 83,
      'plannedMinutes': 900,
      'completedMinutes': 750,
      'totalMinutes': 750,
      'focusMinutes': 480,
      'lifeMinutes': 180,
      'inboxMinutes': 90,
      'bestFocusDay': '2026-10-01',
      'bestFocusMinutes': 240,
      'currentStreak': 5,
      'longestStreak': 12,
      'badgesUnlocked': ['first_session'],
      'xpEarned': 320,
      'previousAdherencePercent': null,
    });
    expect(decoded.weekStart, DateTime(2026, 9, 28));
    expect(decoded.badgesUnlocked, ['first_session']);
    expect(decoded.previousAdherencePercent, isNull);
  });

  test('malformed payloads throw a FormatException', () {
    expect(() => RoundupPayload.fromJson({}), throwsA(isA<FormatException>()));
    expect(
      () => RoundupPayload.fromJson({...payload.toJson(), 'isoWeek': 'forty'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RoundupPayload.fromJson({
        ...payload.toJson(),
        'weekStart': 'next friday',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
