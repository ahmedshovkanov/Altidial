import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceKind', () {
    test('keeps its stable database numbers', () {
      expect(RecurrenceKind.none.dbIndex, 0);
      expect(RecurrenceKind.daily.dbIndex, 1);
      expect(RecurrenceKind.weekdays.dbIndex, 2);
      expect(RecurrenceKind.custom.dbIndex, 3);
    });

    test('is rebuilt from its database number', () {
      for (final kind in RecurrenceKind.values) {
        expect(RecurrenceKind.fromDbIndex(kind.dbIndex), kind);
      }
      expect(() => RecurrenceKind.fromDbIndex(9), throwsArgumentError);
    });
  });

  group('RecurrenceRule basics', () {
    test('none does not repeat and occurs on no weekday', () {
      const rule = RecurrenceRule.none();
      expect(rule.repeats, isFalse);
      expect(rule.effectiveMask, 0);
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(rule.occursOnWeekday(weekday), isFalse);
      }
    });

    test('daily occurs on every weekday', () {
      final rule = RecurrenceRule.daily();
      expect(rule.repeats, isTrue);
      expect(rule.effectiveMask, 127);
      expect(rule.weekdays, {1, 2, 3, 4, 5, 6, 7});
    });

    test('weekdays occurs Monday to Friday', () {
      final rule = RecurrenceRule.weekdays();
      expect(rule.effectiveMask, 31);
      expect(rule.weekdays, {1, 2, 3, 4, 5});
      expect(rule.occursOnWeekday(DateTime.friday), isTrue);
      expect(rule.occursOnWeekday(DateTime.saturday), isFalse);
    });

    test('custom keeps the chosen days, with Monday as bit 0', () {
      final rule = RecurrenceRule.custom({
        DateTime.monday,
        DateTime.wednesday,
        DateTime.sunday,
      });
      expect(rule.weekdayMask, 1 + 4 + 64);
      expect(rule.effectiveMask, 69);
      expect(rule.weekdays, {1, 3, 7});
      expect(rule.occursOnWeekday(DateTime.tuesday), isFalse);
    });

    test('fromStored reads the daily and weekdays shapes back', () {
      expect(
        RecurrenceRule.fromStored(kindIndex: 1, weekdayMask: 0),
        RecurrenceRule.daily(),
      );
      expect(
        RecurrenceRule.fromStored(kindIndex: 2, weekdayMask: 0),
        RecurrenceRule.weekdays(),
      );
    });

    test('fromStored masks a custom rule to seven days', () {
      final rule = RecurrenceRule.fromStored(
        kindIndex: 3,
        weekdayMask: 69 + 128,
      );
      expect(rule.kind, RecurrenceKind.custom);
      expect(rule.weekdayMask, 69);
      expect(rule.weekdays, {1, 3, 7});
    });

    test('a custom rule with no days reads back as none', () {
      expect(
        RecurrenceRule.fromStored(kindIndex: 3, weekdayMask: 0),
        const RecurrenceRule.none(),
      );
    });

    test('an unknown stored kind throws', () {
      expect(
        () => RecurrenceRule.fromStored(kindIndex: 9, weekdayMask: 0),
        throwsArgumentError,
      );
    });

    test('until is a local midnight, whatever time it is given', () {
      final rule = RecurrenceRule.daily(until: DateTime(2026, 12, 31, 18, 30));
      expect(rule.until, DateTime(2026, 12, 31));
      expect(
        rule.withUntil(DateTime(2027, 1, 5, 9)),
        RecurrenceRule.daily(until: DateTime(2027, 1, 5)),
      );
      expect(
        RecurrenceRule.daily(until: DateTime(2026, 12, 31)).withUntil(null),
        RecurrenceRule.daily(),
      );
    });

    test('fromStored normalises the end day too', () {
      expect(
        RecurrenceRule.fromStored(
          kindIndex: 1,
          weekdayMask: 0,
          until: DateTime(2026, 12, 31, 23, 59),
        ),
        RecurrenceRule.daily(until: DateTime(2026, 12, 31)),
      );
    });
  });

  group('occurrenceDates', () {
    test('daily covers every day of the range from the start', () {
      expect(
        occurrenceDates(
          rule: RecurrenceRule.daily(),
          validFrom: DateTime(2026, 10, 5),
          from: DateTime(2026, 10, 1),
          toExclusive: DateTime(2026, 10, 8),
        ),
        [DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 7)],
      );
    });

    test('a rule that does not repeat never occurs', () {
      expect(
        occurrenceDates(
          rule: const RecurrenceRule.none(),
          validFrom: DateTime(2026, 10, 5),
          from: DateTime(2026, 10, 1),
          toExclusive: DateTime(2026, 11, 1),
        ),
        isEmpty,
      );
    });

    test('weekdays skip the weekend', () {
      expect(
        occurrenceDates(
          rule: RecurrenceRule.weekdays(),
          validFrom: DateTime(2026, 10, 1),
          from: DateTime(2026, 10, 1),
          toExclusive: DateTime(2026, 10, 6),
        ),
        [DateTime(2026, 10, 1), DateTime(2026, 10, 2), DateTime(2026, 10, 5)],
      );
    });

    test('custom keeps only its days', () {
      expect(
        occurrenceDates(
          rule: RecurrenceRule.custom({1, 3, 5}),
          validFrom: DateTime(2026, 10, 5),
          from: DateTime(2026, 10, 5),
          toExclusive: DateTime(2026, 10, 13),
        ),
        [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 7),
          DateTime(2026, 10, 9),
          DateTime(2026, 10, 12),
        ],
      );
    });

    test('nothing occurs after the end day, which itself still occurs', () {
      expect(
        occurrenceDates(
          rule: RecurrenceRule.daily(until: DateTime(2026, 10, 6)),
          validFrom: DateTime(2026, 10, 1),
          from: DateTime(2026, 10, 1),
          toExclusive: DateTime(2026, 10, 10),
        ),
        [
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 4),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 6),
        ],
      );
    });

    test('days before the range stay out, even when they match', () {
      expect(
        occurrenceDates(
          rule: RecurrenceRule.daily(),
          validFrom: DateTime(2026, 10, 1),
          from: DateTime(2026, 10, 5),
          toExclusive: DateTime(2026, 10, 7),
        ),
        [DateTime(2026, 10, 5), DateTime(2026, 10, 6)],
      );
    });

    test('an empty range has no occurrences', () {
      final rule = RecurrenceRule.daily();
      expect(
        occurrenceDates(
          rule: rule,
          validFrom: DateTime(2026, 10, 1),
          from: DateTime(2026, 10, 5),
          toExclusive: DateTime(2026, 10, 5),
        ),
        isEmpty,
      );
      expect(
        occurrenceDates(
          rule: rule,
          validFrom: DateTime(2026, 10, 1),
          from: DateTime(2026, 10, 7),
          toExclusive: DateTime(2026, 10, 5),
        ),
        isEmpty,
      );
    });
  });
}
