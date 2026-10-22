import 'package:energy_clock/core/time/month_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startOfMonth gives local midnight on the first', () {
    expect(startOfMonth(DateTime(2026, 10, 17, 14, 30)), DateTime(2026, 10));
  });

  test('addMonths steps across year ends and returns the first', () {
    expect(addMonths(DateTime(2026, 10, 17), 1), DateTime(2026, 11));
    expect(addMonths(DateTime(2026, 12, 31), 1), DateTime(2027));
    expect(addMonths(DateTime(2026, 1, 31), -1), DateTime(2025, 12));
    expect(addMonths(DateTime(2026, 10, 5), 0), DateTime(2026, 10));
    expect(addMonths(DateTime(2026, 10, 5), 14), DateTime(2027, 12));
    expect(addMonths(DateTime(2026, 10, 5), -24), DateTime(2024, 10));
  });

  test('daysInMonth knows month lengths and leap years', () {
    expect(daysInMonth(DateTime(2026, 10)), 31);
    expect(daysInMonth(DateTime(2026, 11)), 30);
    expect(daysInMonth(DateTime(2026, 2)), 28);
    expect(daysInMonth(DateTime(2028, 2)), 29);
    expect(daysInMonth(DateTime(2026, 12, 15)), 31);
  });

  test('monthsBetween counts whole months, in either direction', () {
    expect(monthsBetween(DateTime(2026, 10), DateTime(2026, 10)), 0);
    expect(monthsBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), 1);
    expect(monthsBetween(DateTime(2026, 10), DateTime(2027, 2)), 4);
    expect(monthsBetween(DateTime(2026, 10), DateTime(2025, 12)), -10);
  });

  group('monthWeeks', () {
    test('October 2026 starts on a Thursday and fills five weeks', () {
      final weeks = monthWeeks(DateTime(2026, 10));
      expect(weeks, hasLength(5));
      for (final week in weeks) {
        expect(week, hasLength(7));
      }
      expect(weeks.first.take(3), everyElement(isNull));
      expect(weeks.first[3], DateTime(2026, 10, 1));
      expect(weeks.first[6], DateTime(2026, 10, 4));
      expect(weeks.last[5], DateTime(2026, 10, 31));
      expect(weeks.last[6], isNull);
    });

    test('a month that starts on Monday and has 28 days is four weeks', () {
      final weeks = monthWeeks(DateTime(2027, 2));
      expect(weeks, hasLength(4));
      expect(weeks.first.first, DateTime(2027, 2, 1));
      expect(weeks.last.last, DateTime(2027, 2, 28));
    });

    test('a month can need six weeks', () {
      final weeks = monthWeeks(DateTime(2026, 8));
      expect(weeks, hasLength(6));
      expect(weeks.first[5], DateTime(2026, 8, 1));
      expect(weeks.last[0], DateTime(2026, 8, 31));
    });

    test('every day of the month appears once, in order', () {
      final days = [
        for (final week in monthWeeks(DateTime(2026, 10)))
          for (final day in week)
            if (day != null) day.day,
      ];
      expect(days, [for (var day = 1; day <= 31; day++) day]);
    });

    test('any day of the month gives the same layout', () {
      expect(
        monthWeeks(DateTime(2026, 10, 17)),
        monthWeeks(DateTime(2026, 10)),
      );
    });

    group('first day of week', () {
      test('a Sunday-first October starts its first row on 27 September', () {
        final weeks = monthWeeks(
          DateTime(2026, 10),
          firstWeekday: DateTime.sunday,
        );
        expect(weeks.first, hasLength(7));
        // 1 October 2026 is a Thursday, so Sunday-first leaves four blanks.
        expect(weeks.first.take(4), everyElement(isNull));
        expect(weeks.first[4], DateTime(2026, 10, 1));
        expect(weeks, hasLength(5));
      });

      test('the default is still Monday', () {
        expect(
          monthWeeks(DateTime(2026, 10)),
          monthWeeks(DateTime(2026, 10), firstWeekday: DateTime.monday),
        );
      });
    });
  });
}
