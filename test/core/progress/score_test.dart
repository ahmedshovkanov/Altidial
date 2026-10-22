import 'package:altidial/core/progress/score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = defaultDailyFocusTargetMinutes;

  test('a perfect day scores 100', () {
    final score = scoreFor(
      day: (focus: 180, life: 60, inbox: 60, planned: 300, completed: 300),
      focusTargetMinutes: target,
    );
    expect(score, (adherencePoints: 50, focusPoints: 30, balancePoints: 20));
    expect(score.total, 100);
  });

  test('adherence is proportional and caps at 50', () {
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 200, completed: 100),
        focusTargetMinutes: target,
      ).adherencePoints,
      25,
    );
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 200, completed: 400),
        focusTargetMinutes: target,
      ).adherencePoints,
      50,
    );
  });

  test('an unplanned day still earns focus and balance, not adherence', () {
    final score = scoreFor(
      day: (focus: 90, life: 30, inbox: 0, planned: 0, completed: 120),
      focusTargetMinutes: target,
    );
    expect(score.adherencePoints, 50);
    expect(score.focusPoints, 15);
    expect(score.balancePoints, 8);
  });

  test('focus points scale to the target and cap at 30', () {
    expect(
      scoreFor(
        day: (focus: 360, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: target,
      ).focusPoints,
      30,
    );
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: 120,
      ).focusPoints,
      15,
    );
  });

  test('a non-positive target reads as the default', () {
    expect(
      scoreFor(
        day: (focus: 90, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: 0,
      ).focusPoints,
      15,
    );
  });

  test('balance pays 20, 8 or 0', () {
    int balance(DayMinutes day) =>
        scoreFor(day: day, focusTargetMinutes: target).balancePoints;
    expect(
      balance((focus: 10, life: 10, inbox: 10, planned: 30, completed: 30)),
      20,
    );
    expect(
      balance((focus: 10, life: 10, inbox: 0, planned: 30, completed: 20)),
      8,
    );
    expect(
      balance((focus: 10, life: 0, inbox: 0, planned: 30, completed: 10)),
      0,
    );
  });

  test('a day with nothing scores nothing', () {
    expect(
      scoreFor(
        day: (focus: 0, life: 0, inbox: 0, planned: 0, completed: 0),
        focusTargetMinutes: target,
      ).total,
      0,
    );
  });
}
