import 'package:energy_clock/core/progress/badges.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joinWords reads naturally', () {
    expect(Strings.joinWords(const []), '');
    expect(Strings.joinWords(const ['Focus']), 'Focus');
    expect(Strings.joinWords(const ['Focus', 'Life']), 'Focus and Life');
    expect(
      Strings.joinWords(const ['Focus', 'Life', 'Inbox']),
      'Focus, Life and Inbox',
    );
  });

  test('event counts are pluralised', () {
    expect(Strings.eventCount(0), '0 events');
    expect(Strings.eventCount(1), '1 event');
    expect(Strings.eventCount(5), '5 events');
  });

  test('now-card copy', () {
    expect(Strings.nowTimeLeft('42m'), '42m left');
    expect(Strings.nowUntil('11:00'), 'until 11:00');
    expect(Strings.nowStartsAt('12:30', '40m'), 'Starts at 12:30 · in 40m');
    expect(Strings.nowOverlapping(2), '+2 overlapping');
    expect(Strings.plannedSummary(5, '6h 30m'), '5 events · 6h 30m planned');
    expect(Strings.plannedDuration('6h 30m'), '6h 30m planned');
    expect(Strings.pastSummary(1, '1h'), '1 event · 1h');
    expect(Strings.dayCountTitle('Tuesday', 5), 'Tuesday · 5 events');
  });

  test('screen-reader copy reads as one sentence', () {
    expect(
      Strings.eventSemantics('Deep work', 'Focus', '09:00', '11:00', '2 hours'),
      'Deep work, Focus, 09:00 to 11:00, 2 hours',
    );
    expect(
      Strings.nowSemantics('Deep work', 'Focus', '42 minutes'),
      'Now: Deep work, Focus, 42 minutes left',
    );
    expect(
      Strings.nextSemantics('Lunch', 'Life', '40 minutes'),
      'Next up: Lunch, Life, starts in 40 minutes',
    );
    expect(
      Strings.dayLoadSemantics('Focus 4 hours, Life 2 hours'),
      'Planned load: Focus 4 hours, Life 2 hours',
    );
    expect(Strings.tabSemantics('Clock', 1, 4), 'Clock, tab 1 of 4');
  });

  test('week day semantics mention planned tones and today', () {
    expect(
      Strings.weekDaySemantics(
        'Tuesday 6 October',
        tones: 'Focus and Life',
        isToday: true,
      ),
      'Tuesday 6 October, Focus and Life planned, today',
    );
    expect(
      Strings.weekDaySemantics('Tuesday 6 October', tones: '', isToday: false),
      'Tuesday 6 October',
    );
  });

  test('plan list titles', () {
    expect(Strings.planTitleToday, "Today's plan");
    expect(Strings.planTitleFor('Tuesday'), "Tuesday's plan");
  });

  test('weekdayShortStarting rotates the short names', () {
    expect(Strings.weekdayShortStarting(DateTime.sunday), [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ]);
    expect(Strings.weekdayShortStarting(DateTime.monday), Strings.weekdayShort);
    expect(Strings.weekdayShortStarting(DateTime.saturday), hasLength(7));
  });

  test('statistics copy formats its numbers', () {
    expect(Strings.statsAdherence(83), '83% adherence');
    expect(Strings.statsAbandonedCount(1, 3), '1 of 3');
    expect(
      Strings.statsPlannedDone('2h', '1h 30m'),
      '2h planned · 1h 30m done',
    );
  });

  test('every badge has a title and a description', () {
    expect(badgeDefinitions, hasLength(10));
    for (final badge in badgeDefinitions) {
      expect(badge.title, isNotEmpty);
      expect(badge.description, isNotEmpty);
    }
  });

  test('profile copy formats its numbers', () {
    expect(Strings.profileLevel(3), 'Level 3');
    expect(Strings.profileXp(120, 300), '120 / 300 XP');
    expect(Strings.profileStreak(1), '1-day streak');
    expect(Strings.profilePoints(8, 20), '8 / 20');
  });

  test('roundup copy formats its numbers', () {
    expect(Strings.roundupWeek(41), 'Week 41');
    expect(Strings.roundupXp(400), '400 XP');
    expect(
      Strings.roundupPreviousAdherence(71),
      'Previous week: 71% adherence',
    );
  });

  test('settings copy names its actions', () {
    expect(Strings.settingsRecalculateConfirm, 'Rebuild');
    expect(Strings.settingsEraseConfirm, 'Erase');
    expect(Strings.settingsExportSubject, 'Energy Clock export');
  });

  test('breathing copy formats its numbers', () {
    expect(Strings.breatheCount(3, 8), 'Breath 3 of 8');
    expect(Strings.breatheDoneBody(1), '1 calm breath.');
    expect(Strings.breatheDoneBody(8), '8 calm breaths.');
    expect(Strings.deckBreatheTitle, 'Take a breath');
    expect(Strings.breatheDoneTitle, "You're here");
  });

  test('breathing phase semantics read as one sentence', () {
    expect(
      Strings.breathePhaseSemantics(Strings.breatheInhale, 3),
      'Breathe in, 3 seconds',
    );
    expect(
      Strings.breathePhaseSemantics(Strings.breatheExhale, 1),
      'Breathe out, 1 second',
    );
  });
}
