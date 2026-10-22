import 'package:altidial/core/strings.dart';
import 'package:altidial/features/calendar/widgets/month_header.dart';
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

  Widget header({
    bool isCurrentMonth = true,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onToday,
  }) {
    return MonthHeader(
      month: DateTime(2026, 10),
      isCurrentMonth: isCurrentMonth,
      onPrevious: onPrevious ?? () {},
      onNext: onNext ?? () {},
      onToday: onToday ?? () {},
    );
  }

  testWidgets('shows the month and the year', (tester) async {
    await tester.pumpWidget(harness.app(header()));
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('the title is a screen reader heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(header()));

    expect(
      tester.getSemantics(find.text('October 2026')),
      matchesSemantics(label: 'October 2026', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('the arrows call onPrevious and onNext', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        header(
          onPrevious: () => calls.add('previous'),
          onNext: () => calls.add('next'),
        ),
      ),
    );

    await tester.tap(find.byTooltip(Strings.previousMonth));
    await tester.tap(find.byTooltip(Strings.nextMonth));

    expect(calls, ['previous', 'next']);
  });

  testWidgets('the Today pill shows only away from the current month', (
    tester,
  ) async {
    var today = 0;
    await tester.pumpWidget(harness.app(header()));
    expect(find.text(Strings.today), findsNothing);

    await tester.pumpWidget(
      harness.app(header(isCurrentMonth: false, onToday: () => today++)),
    );
    await tester.tap(find.text(Strings.today));

    expect(today, 1);
  });

  testWidgets('the arrows are at least 44 x 44', (tester) async {
    await tester.pumpWidget(harness.app(header()));

    for (final tooltip in [Strings.previousMonth, Strings.nextMonth]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(44), reason: tooltip);
      expect(size.height, greaterThanOrEqualTo(44), reason: tooltip);
    }
  });

  for (final textScale in [1.0, 2.0, 3.12]) {
    testWidgets(
      'a long month name fits 320 pt at text ${(textScale * 100).toInt()}%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness.app(
            MonthHeader(
              month: DateTime(2026, 9),
              isCurrentMonth: false,
              onPrevious: () {},
              onNext: () {},
              onToday: () {},
            ),
            textScale: textScale,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
