import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final day = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Widget cell({
    Map<Tone, int> minutes = const {},
    bool isToday = false,
    bool isPast = false,
    VoidCallback? onTap,
    double size = 48,
  }) {
    return Center(
      child: DayCell(
        day: day,
        size: size,
        minutes: minutes,
        isToday: isToday,
        isPast: isPast,
        onTap: onTap ?? () {},
      ),
    );
  }

  testWidgets('shows the day of the month', (tester) async {
    await tester.pumpWidget(harness.app(cell()));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('tapping the cell calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness.app(cell(onTap: () => taps++)));

    await tester.tap(find.byType(DayCell));

    expect(taps, 1);
  });

  testWidgets('a future day has an ink number, a past day a muted one', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(cell()));
    final context = tester.element(find.byType(DayCell));
    final colors = context.appColors;
    expect(tester.widget<Text>(find.text('7')).style!.color, colors.ink);

    await tester.pumpWidget(harness.app(cell(isPast: true)));
    expect(tester.widget<Text>(find.text('7')).style!.color, colors.muted);
  });

  testWidgets('today has an ink disc and the number in onInk', (tester) async {
    await tester.pumpWidget(harness.app(cell(isToday: true)));
    final colors = tester.element(find.byType(DayCell)).appColors;

    expect(tester.widget<Text>(find.text('7')).style!.color, colors.onInk);
    final disc = find.byKey(const ValueKey('day-cell-today-disc'));
    expect(disc, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(disc).decoration as BoxDecoration;
    expect(decoration.color, colors.ink);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('other days have no disc', (tester) async {
    await tester.pumpWidget(harness.app(cell()));
    expect(find.byKey(const ValueKey('day-cell-today-disc')), findsNothing);
  });

  testWidgets('is read aloud with the date, the tones and the minutes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness.app(cell(minutes: {Tone.focus: 180, Tone.life: 60})),
    );

    expect(
      tester.getSemantics(find.byType(DayCell)),
      matchesSemantics(
        label: 'Wednesday 7 October, Focus 3 hours and Life 1 hour planned',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('says today, and says nothing about tones on an empty day', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(cell(isToday: true)));

    expect(
      tester.getSemantics(find.byType(DayCell)),
      matchesSemantics(
        label: 'Wednesday 7 October, today',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('keeps its size at the largest text size', (tester) async {
    await tester.pumpWidget(
      harness.app(cell(isToday: true, size: 44), textScale: 3.12),
    );

    expect(tester.getSize(find.byType(DayCell)), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('is the size it is given, at least 40 points', (tester) async {
    await tester.pumpWidget(harness.app(cell(size: 40)));
    expect(tester.getSize(find.byType(DayCell)), const Size(40, 40));
  });
}
