import 'package:energy_clock/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startOfDay strips the time component', () {
    final result = startOfDay(DateTime(2026, 8, 23, 14, 37, 12));
    expect(result, DateTime(2026, 8, 23));
  });

  test('minuteOfDay counts minutes since local midnight', () {
    expect(minuteOfDay(DateTime(2026, 8, 23, 0, 0)), 0);
    expect(minuteOfDay(DateTime(2026, 8, 23, 9, 30)), 570);
    expect(minuteOfDay(DateTime(2026, 8, 23, 23, 59)), 1439);
  });

  test('formatMinuteOfDay zero-pads and renders end-of-day as 24:00', () {
    expect(formatMinuteOfDay(0), '00:00');
    expect(formatMinuteOfDay(540), '09:00');
    expect(formatMinuteOfDay(1439), '23:59');
    expect(formatMinuteOfDay(1440), '24:00');
  });

  test('formatMinuteRange joins with an en dash', () {
    expect(formatMinuteRange(540, 720), '09:00 – 12:00');
  });

  test('formatDurationMinutes drops empty units', () {
    expect(formatDurationMinutes(45), '45m');
    expect(formatDurationMinutes(90), '1h 30m');
    expect(formatDurationMinutes(120), '2h');
  });

  test('isPastDay is false for today and true for yesterday', () {
    final now = DateTime(2026, 8, 23, 10, 0);
    expect(isPastDay(DateTime(2026, 8, 23), now: now), isFalse);
    expect(isPastDay(DateTime(2026, 8, 24), now: now), isFalse);
    expect(isPastDay(DateTime(2026, 8, 22), now: now), isTrue);
  });

  test('nextDay advances one calendar day and stays at midnight', () {
    expect(nextDay(DateTime(2026, 8, 23)), DateTime(2026, 8, 24));
    expect(nextDay(DateTime(2026, 8, 23, 17, 42)), DateTime(2026, 8, 24));
  });

  test('nextDay rolls over month and year boundaries', () {
    expect(nextDay(DateTime(2027, 1, 31)), DateTime(2027, 2, 1));
    expect(nextDay(DateTime(2027, 12, 31)), DateTime(2028, 1, 1));
    expect(nextDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
  });

  test('previousDay steps back one calendar day', () {
    expect(previousDay(DateTime(2026, 8, 23)), DateTime(2026, 8, 22));
    expect(previousDay(DateTime(2027, 3, 1)), DateTime(2027, 2, 28));
    expect(previousDay(DateTime(2028, 1, 1)), DateTime(2027, 12, 31));
  });
}
