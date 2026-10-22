import 'package:energy_clock/core/progress/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  List<DateTime> days(List<int> octoberDays) => [
    for (final day in octoberDays) DateTime(2026, 10, day),
  ];

  test('an unbroken run to today counts fully', () {
    expect(streaks(days([3, 4, 5, 6, 7]), today: today), (
      current: 5,
      longest: 5,
      lastDate: DateTime(2026, 10, 7),
    ));
  });

  test('a run ending yesterday still counts today', () {
    expect(streaks(days([5, 6]), today: today).current, 2);
  });

  test('a gap before today breaks the current run but not the longest', () {
    final result = streaks(days([1, 2, 3, 5]), today: today);
    expect(result.current, 0);
    expect(result.longest, 3);
    expect(result.lastDate, DateTime(2026, 10, 5));
  });

  test('duplicates and shuffling do not matter', () {
    expect(streaks(days([7, 5, 6, 5, 7]), today: today).current, 3);
  });

  test('no qualifying days means no streak', () {
    expect(streaks(const [], today: today), (
      current: 0,
      longest: 0,
      lastDate: null,
    ));
  });

  test('a future day never extends the run', () {
    expect(streaks(days([7, 8]), today: today).current, 1);
  });
}
