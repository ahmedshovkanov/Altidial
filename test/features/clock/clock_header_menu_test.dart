import 'package:altidial/core/strings.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/clock_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

Finder moreButton() => find.byTooltip(Strings.moreActions);

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  testWidgets('there is no menu button when no action applies', (tester) async {
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(moreButton(), findsNothing);
  });

  testWidgets('lists exactly the actions that were given', (tester) async {
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();

    expect(find.text(Strings.saveAsTemplate), findsOneWidget);
    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsNothing);
  });

  testWidgets('lists all three when all are given', (tester) async {
    await tester.pumpWidget(
      harness.app(
        ClockHeader(
          onAdd: () {},
          onSaveTemplate: () {},
          onCopyYesterday: () {},
          onApplyTemplate: () {},
        ),
      ),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();

    expect(find.text(Strings.saveAsTemplate), findsOneWidget);
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('choosing an action calls it and closes the menu', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        ClockHeader(
          onAdd: () {},
          onSaveTemplate: () => calls.add('save'),
          onCopyYesterday: () => calls.add('copy'),
          onApplyTemplate: () => calls.add('apply'),
        ),
      ),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.copyYesterday));
    await tester.pumpAndSettle();

    expect(calls, ['copy']);
    expect(find.text(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day has the menu but no + button', (tester) async {
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 5));
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    expect(moreButton(), findsOneWidget);
    expect(find.byTooltip(Strings.addEvent), findsNothing);
    expect(find.text(Strings.readOnlyChip), findsOneWidget);
  });

  testWidgets('the menu button is at least 44 x 44', (tester) async {
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    final size = tester.getSize(moreButton());
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  for (final textScale in [1.0, 2.0, 3.12]) {
    testWidgets(
      'a past day with every control fits 320 pt at text ${(textScale * 100).toInt()}%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        harness.container
            .read(selectedDateProvider.notifier)
            .select(DateTime(2026, 10, 5));

        await tester.pumpWidget(
          harness.app(
            ClockHeader(onAdd: () {}, onSaveTemplate: () {}),
            textScale: textScale,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
