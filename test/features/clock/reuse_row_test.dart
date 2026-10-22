import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  testWidgets('shows both buttons and calls the one that is tapped', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        ReuseRow(
          onCopyYesterday: () => calls.add('copy'),
          onApplyTemplate: () => calls.add('apply'),
        ),
      ),
    );

    await tester.tap(find.text(Strings.copyYesterday));
    await tester.tap(find.text(Strings.applyTemplate));

    expect(calls, ['copy', 'apply']);
  });

  testWidgets('leaves Copy yesterday out when there is nothing to copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: null, onApplyTemplate: () {})),
    );

    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('the buttons are read as buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {})),
    );

    for (final label in [Strings.copyYesterday, Strings.applyTemplate]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });

  testWidgets('the row is ${ReuseRow.height} points tall', (tester) async {
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {})),
    );

    expect(tester.getSize(find.byType(ReuseRow)).height, ReuseRow.height);
  });

  for (final width in [320.0, 375.0]) {
    for (final textScale in [1.0, 1.3, 3.12]) {
      testWidgets(
        'fits ${width.toInt()} pt at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            harness.app(
              ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {}),
              textScale: textScale,
            ),
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(ReuseRow)).height, ReuseRow.height);
        },
      );
    }
  }
}
