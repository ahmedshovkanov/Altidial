import 'package:altidial/features/clock/clock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a tall phone shows everything', () {
    test('iPhone 17 Pro: 697 pt of content height', () {
      final plan = ClockLayoutPlan.forHeight(697);
      expect(plan.showDayLoad, isTrue);
      expect(plan.compactNowCard, isFalse);
      expect(plan.showHeaderDate, isTrue);
      expect(plan.showWeekDots, isTrue);
      // 697 - header 48 - strip 60 - three 8 pt gaps - Now card 96 - bar 68.
      expect(plan.dialHeight, closeTo(401, 1e-9));
    });
  });

  group('a short phone gives way in a fixed order', () {
    test('iPhone SE: the day-load bar goes first', () {
      final plan = ClockLayoutPlan.forHeight(563);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isFalse);
      expect(plan.showHeaderDate, isTrue);
      // 563 - 48 - 60 - two gaps - 96.
      expect(plan.dialHeight, closeTo(343, 1e-9));
    });

    test('shorter still: the Now card becomes one row', () {
      final plan = ClockLayoutPlan.forHeight(470);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isTrue);
      expect(plan.showHeaderDate, isTrue);
    });

    test('the card is one row exactly when the dial would be under 260', () {
      // Without the bar: height - 48 - 60 - two gaps - 96 = height - 220.
      expect(
        ClockLayoutPlan.forHeight(480, hasDayLoad: false).compactNowCard,
        isFalse,
      );
      expect(
        ClockLayoutPlan.forHeight(479, hasDayLoad: false).compactNowCard,
        isTrue,
      );
    });

    test('shorter again: the header loses its date line', () {
      final plan = ClockLayoutPlan.forHeight(400);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isTrue);
      expect(plan.showHeaderDate, isFalse);
    });

    test('a day with no events never reserves room for the bar', () {
      final plan = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
      expect(plan.showDayLoad, isFalse);
      // 697 - 48 - 60 - two gaps - 96.
      expect(plan.dialHeight, closeTo(477, 1e-9));
    });

    test('the bar is dropped exactly when the dial would be under 300', () {
      // With the bar: height - 48 - 60 - 24 - 96 - 68 = height - 296.
      expect(ClockLayoutPlan.forHeight(596).showDayLoad, isTrue);
      expect(ClockLayoutPlan.forHeight(595).showDayLoad, isFalse);
    });
  });

  group('large text', () {
    test('above 130% the bar and the dots go and the card is one row', () {
      final plan = ClockLayoutPlan.forHeight(900, textScale: 1.5);
      expect(plan.showDayLoad, isFalse);
      expect(plan.showWeekDots, isFalse);
      expect(plan.compactNowCard, isTrue);
    });

    test('exactly 130% is still normal', () {
      final plan = ClockLayoutPlan.forHeight(900, textScale: 1.3);
      expect(plan.showWeekDots, isTrue);
    });

    test('at 200% on an iPhone SE the dial still has room', () {
      final plan = ClockLayoutPlan.forHeight(563, textScale: 2);
      expect(plan.dialHeight, greaterThanOrEqualTo(ClockLayoutPlan.minDial));
      expect(plan.showHeaderDate, isTrue);
    });

    test('a text scale beyond 200% is treated as 200%', () {
      final a = ClockLayoutPlan.forHeight(700, textScale: 2);
      final b = ClockLayoutPlan.forHeight(700, textScale: 3.1);
      expect(b.dialHeight, a.dialHeight);
    });
  });

  test('the thresholds', () {
    expect(ClockLayoutPlan.gap, 8);
    expect(ClockLayoutPlan.smallDial, 300);
    expect(ClockLayoutPlan.tinyDial, 260);
    expect(ClockLayoutPlan.minDial, 240);
    expect(ClockLayoutPlan.largeTextScale, 1.3);
  });
}
