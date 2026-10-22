import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

Finder addButton() => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == Strings.addEvent,
);

void main() {
  late ClockHarness harness;

  tearDown(() {
    harness.dispose();
  });

  testWidgets('shows the day name and the date', (tester) async {
    harness = ClockHarness(); // Wednesday 7 October 2026
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('7 October 2026'), findsOneWidget);
  });

  testWidgets('the date line can be dropped on a very short screen', (
    tester,
  ) async {
    harness = ClockHarness();
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, showDate: false)),
    );
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('7 October 2026'), findsNothing);
  });

  testWidgets('hides the Today pill on today and shows it elsewhere', (
    tester,
  ) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(find.text(Strings.today), findsNothing);

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 9));
    await tester.pump();
    expect(find.text(Strings.today), findsOneWidget);
  });

  testWidgets('tapping Today returns to the clock\'s today', (tester) async {
    harness = ClockHarness(selected: DateTime(2026, 12, 25));
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    await tester.tap(find.text(Strings.today));
    await tester.pump();

    expect(harness.container.read(selectedDateProvider), DateTime(2026, 10, 7));
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('the + button calls onAdd on an editable day', (tester) async {
    harness = ClockHarness();
    var adds = 0;
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () => adds++)));

    await tester.tap(addButton());
    expect(adds, 1);
  });

  testWidgets('a past day shows the Read-only chip and has no + button', (
    tester,
  ) async {
    harness = ClockHarness(selected: DateTime(2026, 10, 6));
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    expect(find.text(Strings.readOnlyChip), findsOneWidget);
    expect(addButton(), findsNothing);
  });

  testWidgets('an editable day has no Read-only chip', (tester) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(find.text(Strings.readOnlyChip), findsNothing);
  });

  testWidgets('the + button is at least 44 x 44', (tester) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    final size = tester.getSize(addButton());
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a long day name at double text size does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    harness = ClockHarness(selected: DateTime(2026, 10, 7));
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}), textScale: 2),
    );
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 9));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('height budgets', () {
    expect(ClockHeader.height, 48);
    expect(ClockHeader.heightFor(1, showDate: true), 48);
    expect(ClockHeader.heightFor(1, showDate: false), 34);
    expect(ClockHeader.heightFor(2, showDate: true), 92);
  });
}
