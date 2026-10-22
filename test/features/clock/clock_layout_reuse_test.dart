import 'package:energy_clock/features/clock/clock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a day that needs no reuse row plans exactly as before', () {
    final plain = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
    final explicit = ClockLayoutPlan.forHeight(
      697,
      hasDayLoad: false,
      hasReuseTools: false,
    );

    expect(plain.showReuseTools, isFalse);
    expect(explicit.dialHeight, plain.dialHeight);
  });

  test('a tall phone shows the row and the dial gives up 52 points', () {
    final without = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
    final with_ = ClockLayoutPlan.forHeight(
      697,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(with_.showReuseTools, isTrue);
    expect(without.dialHeight - with_.dialHeight, closeTo(52, 1e-9));
    expect(with_.compactNowCard, isFalse);
    expect(with_.showHeaderDate, isTrue);
  });

  test('the row is dropped exactly when the dial would be under 300', () {
    // Without the day-load bar: dial = height - 220 - 52 with the row.
    expect(
      ClockLayoutPlan.forHeight(
        572,
        hasDayLoad: false,
        hasReuseTools: true,
      ).showReuseTools,
      isTrue,
    );
    expect(
      ClockLayoutPlan.forHeight(
        571,
        hasDayLoad: false,
        hasReuseTools: true,
      ).showReuseTools,
      isFalse,
    );
  });

  test('the row goes before the Now card shrinks', () {
    final plan = ClockLayoutPlan.forHeight(
      563,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isFalse);
    expect(plan.compactNowCard, isFalse);
    expect(plan.dialHeight, closeTo(343, 1e-9));
  });

  test('large text never shows the row', () {
    final plan = ClockLayoutPlan.forHeight(
      1400,
      textScale: 1.31,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isFalse);
  });

  test('text at 130% still has room for it', () {
    final plan = ClockLayoutPlan.forHeight(
      1400,
      textScale: 1.3,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isTrue);
  });
}
