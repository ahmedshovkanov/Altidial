import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/recurrence/recurrence_text.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names the common shapes', () {
    expect(describeRecurrence(RecurrenceRule.daily()), 'Every day');
    expect(describeRecurrence(RecurrenceRule.weekdays()), 'Weekdays');
    expect(describeRecurrence(const RecurrenceRule.none()), 'Does not repeat');
  });

  test('lists the days of a custom rule', () {
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 3, 5})),
      'Every Mon, Wed and Fri',
    );
    expect(describeRecurrence(RecurrenceRule.custom({6})), 'Every Sat');
    expect(
      describeRecurrence(RecurrenceRule.custom({2, 4})),
      'Every Tue and Thu',
    );
  });

  test('a custom rule that is really every day or weekdays says so', () {
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 2, 3, 4, 5, 6, 7})),
      'Every day',
    );
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 2, 3, 4, 5})),
      'Weekdays',
    );
  });

  test('adds the end day', () {
    expect(
      describeRecurrence(RecurrenceRule.daily(until: DateTime(2026, 12, 31))),
      'Every day, until 31 Dec 2026',
    );
    expect(
      describeRecurrence(
        RecurrenceRule.custom({1, 3}, until: DateTime(2027, 1, 5)),
      ),
      'Every Mon and Wed, until 5 Jan 2027',
    );
  });

  test('the weekday lists run Monday first and have seven entries', () {
    expect(Strings.weekdayShort, hasLength(7));
    expect(Strings.weekdayLong, hasLength(7));
    expect(Strings.weekdayInitials, hasLength(7));
    expect(Strings.weekdayShort.first, 'Mon');
    expect(Strings.weekdayLong.last, 'Sunday');
    expect(Strings.weekdayInitials.first, 'M');
  });
}
