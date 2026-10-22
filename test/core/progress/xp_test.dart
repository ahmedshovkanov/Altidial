import 'package:altidial/core/progress/xp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessions pay a point a minute, focus pays half as much again', () {
    expect(sessionXpMinutes(60, focus: false), 60);
    expect(sessionXpMinutes(60, focus: true), 90);
    expect(sessionXpMinutes(1, focus: true), 2);
  });

  test('badges pay fifty each', () {
    expect(badgeXp(0), 0);
    expect(badgeXp(3), 150);
  });

  test('streaks pay five a day past the first week of each run', () {
    // One 10-day run: 3 paid days.
    expect(streakXp([for (var d = 1; d <= 10; d++) DateTime(2026, 10, d)]), 15);
    // Two short runs pay nothing; a 7-day run pays nothing either.
    expect(
      streakXp([
        for (var d = 1; d <= 4; d++) DateTime(2026, 10, d),
        for (var d = 20; d <= 26; d++) DateTime(2026, 10, d),
      ]),
      0,
    );
  });

  test('levels rise every hundred-times-triangular XP', () {
    expect(xpToReachLevel(1), 0);
    expect(xpToReachLevel(2), 100);
    expect(xpToReachLevel(3), 300);
    expect(xpToReachLevel(4), 600);
    expect(levelForXp(0), 1);
    expect(levelForXp(99), 1);
    expect(levelForXp(100), 2);
    expect(levelForXp(599), 3);
    expect(levelForXp(600), 4);
  });

  test('the progress bar helpers agree with the level', () {
    expect(xpIntoLevel(250), (current: 250, start: 100, end: 300));
    expect(xpForNextLevel(1), 100);
  });
}
