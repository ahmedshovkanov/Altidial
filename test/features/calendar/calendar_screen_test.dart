import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/calendar/calendar_screen.dart';
import 'package:altidial/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Finder cell(int month, int day, {int year = 2026}) => find.byKey(
    ValueKey(
      'day-$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    ),
  );

  Widget screen({
    DateTime? today_,
    ValueChanged<DateTime>? onOpenDay,
    double inset = 0,
  }) {
    return TabBarInset(
      height: inset,
      child: CalendarScreen(
        today: today_ ?? today,
        onOpenDay: onOpenDay ?? (_) {},
      ),
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    Widget? child,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(child ?? screen(), reduceMotion: reduceMotion),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the current month, with today marked', (tester) async {
    await mount(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
    expect(
      find.descendant(
        of: cell(10, 7),
        matching: find.byKey(const ValueKey('day-cell-today-disc')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the next arrow shows the next month and the Today pill', (
    tester,
  ) async {
    await mount(tester);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsOneWidget);
    expect(cell(11, 30), findsOneWidget);
    expect(cell(10, 7), findsNothing);
  });

  testWidgets('the previous arrow shows the month before', (tester) async {
    await mount(tester);

    await tester.tap(find.byTooltip(Strings.previousMonth));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(cell(9, 30), findsOneWidget);
  });

  testWidgets('swiping moves between months', (tester) async {
    await mount(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('the Today pill comes back to the current month', (tester) async {
    await mount(tester);
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byTooltip(Strings.nextMonth));
      await tester.pumpAndSettle();
    }
    expect(find.text('December 2027'), findsOneWidget);

    await tester.tap(find.text(Strings.today));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('it can go back as well as forward, across a year end', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip(Strings.previousMonth));
      await tester.pumpAndSettle();
    }
    expect(find.text('December 2025'), findsOneWidget);
  });

  testWidgets('tapping a day opens it', (tester) async {
    final opened = <DateTime>[];
    await mount(tester, child: screen(onOpenDay: opened.add));

    await tester.tap(cell(10, 20));
    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();
    await tester.tap(cell(11, 3));

    expect(opened, [DateTime(2026, 10, 20), DateTime(2026, 11, 3)]);
  });

  testWidgets('each month shows its own plans', (tester) async {
    final handle = tester.ensureSemantics();
    await harness.repository.createEvent(
      day: DateTime(2026, 11, 3),
      title: 'Planning',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await mount(tester);
    expect(find.text(Strings.calendarEmptyMonth), findsOneWidget);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    expect(find.text(Strings.calendarEmptyMonth), findsNothing);
    expect(
      tester.getSemantics(cell(11, 3)).label,
      'Tuesday 3 November, Focus 1 hour planned',
    );
    handle.dispose();
  });

  testWidgets('under Reduce Motion a month change jumps at once', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pump();

    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('when the month rolls over, the old one gets a Today pill', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text(Strings.today), findsNothing);

    // Midnight passes on 31 October: today is now 1 November.
    await tester.pumpWidget(harness.app(screen(today_: DateTime(2026, 11, 1))));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsOneWidget);

    await tester.tap(find.text(Strings.today));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('leaves room for the floating tab bar', (tester) async {
    await mount(tester, child: screen(inset: 84));

    final legendBottom = tester.getBottomLeft(find.text(Tone.inbox.label)).dy;
    expect(legendBottom, lessThanOrEqualTo(874 - 84));
    expect(find.byType(DayCell), findsNWidgets(31));
  });
}
