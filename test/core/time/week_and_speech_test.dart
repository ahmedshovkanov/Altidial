import 'package:altidial/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spokenDurationMinutes', () {
    test('minutes only', () {
      expect(spokenDurationMinutes(45), '45 minutes');
      expect(spokenDurationMinutes(1), '1 minute');
    });

    test('whole hours', () {
      expect(spokenDurationMinutes(60), '1 hour');
      expect(spokenDurationMinutes(120), '2 hours');
    });

    test('hours and minutes', () {
      expect(spokenDurationMinutes(90), '1 hour 30 minutes');
      expect(spokenDurationMinutes(61), '1 hour 1 minute');
    });
  });

  group('startOfWeek', () {
    test('a Saturday maps to the Monday before it', () {
      // 3 October 2026 is a Saturday.
      expect(startOfWeek(DateTime(2026, 10, 3)), DateTime(2026, 9, 28));
    });

    test('a Monday maps to itself', () {
      expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
    });

    test('a Sunday belongs to the week that started six days earlier', () {
      expect(startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 9, 28));
    });

    test('ignores the time of day', () {
      expect(startOfWeek(DateTime(2026, 10, 3, 23, 59)), DateTime(2026, 9, 28));
    });

    test('is calendar arithmetic across a month boundary', () {
      expect(startOfWeek(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    });
  });

  test(
    'daysOfWeek returns seven consecutive local midnights, Monday first',
    () {
      final days = daysOfWeek(DateTime(2026, 10, 3, 15));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 10, 4));
      for (var i = 1; i < days.length; i++) {
        expect(days[i], DateTime(2026, 9, 28 + i));
      }
    },
  );

  group('first day of week', () {
    test('a week can start on Sunday', () {
      // Wednesday 7 October 2026 sits in the Sunday 4 – Saturday 10 week.
      expect(
        startOfWeek(DateTime(2026, 10, 7), firstWeekday: DateTime.sunday),
        DateTime(2026, 10, 4),
      );
      // Monday belongs to the week that began the previous Sunday.
      expect(
        startOfWeek(DateTime(2026, 10, 5), firstWeekday: DateTime.sunday),
        DateTime(2026, 10, 4),
      );
    });

    test('a Sunday-start week enumerates Sunday first', () {
      final days = daysOfWeek(
        DateTime(2026, 10, 7),
        firstWeekday: DateTime.sunday,
      );
      expect(days.first, DateTime(2026, 10, 4));
      expect(days.last, DateTime(2026, 10, 10));
      expect(days, hasLength(7));
    });

    test('the default is still Monday', () {
      expect(startOfWeek(DateTime(2026, 10, 7)), DateTime(2026, 10, 5));
      expect(
        startOfWeek(DateTime(2026, 10, 7), firstWeekday: DateTime.monday),
        DateTime(2026, 10, 5),
      );
    });
  });
}
