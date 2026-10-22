import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known dates land in their ISO weeks', () {
    expect(isoWeekOf(DateTime(2026, 1, 1)), (year: 2026, week: 1));
    expect(isoWeekOf(DateTime(2025, 12, 29)), (year: 2026, week: 1));
    expect(isoWeekOf(DateTime(2026, 12, 31)), (year: 2026, week: 53));
    expect(isoWeekOf(DateTime(2026, 10, 7)), (year: 2026, week: 41));
    expect(isoWeekOf(DateTime(2025, 12, 28)), (year: 2025, week: 52));
  });

  test('week starts are the Mondays of those weeks', () {
    expect(isoWeekStart(2026, 41), DateTime(2026, 10, 5));
    expect(isoWeekStart(2026, 1), DateTime(2025, 12, 29));
    expect(isoWeekStart(2026, 53), DateTime(2026, 12, 28));
  });

  test('every date sits inside its own week', () {
    for (final date in [
      DateTime(2026, 1, 1),
      DateTime(2026, 3, 8), // US clocks change; local math must not care
      DateTime(2026, 10, 7),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 3),
    ]) {
      final week = isoWeekOf(date);
      final start = isoWeekStart(week.year, week.week);
      expect(start.isAfter(date), isFalse);
      expect(
        date.isAfter(DateTime(start.year, start.month, start.day + 6)),
        isFalse,
      );
    }
  });

  test('week 1 always contains the 4th of January', () {
    for (final year in [2025, 2026, 2027]) {
      expect(isoWeekOf(DateTime(year, 1, 4)), (year: year, week: 1));
    }
  });

  test('a time of day never changes the week', () {
    expect(
      isoWeekOf(DateTime(2026, 10, 7, 23, 59)),
      isoWeekOf(DateTime(2026, 10, 7)),
    );
  });
}
