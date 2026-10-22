import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/calendar/widgets/day_cell.dart';
import 'package:altidial/features/calendar/widgets/month_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);
  final october = DateTime(2026, 10);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Finder cell(DateTime day) => find.byKey(
    ValueKey(
      'day-${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    ),
  );

  Future<void> mount(
    WidgetTester tester, {
    DateTime? month,
    ValueChanged<DateTime>? onOpenDay,
    Size size = const Size(402, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        MonthPage(
          month: month ?? october,
          today: today,
          onOpenDay: onOpenDay ?? (_) {},
        ),
        textScale: textScale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the weekday labels, Monday first', (tester) async {
    await mount(tester);

    final labels = [
      for (final name in Strings.weekdayShort)
        tester.getTopLeft(find.text(name)).dx,
    ];
    expect(labels, orderedEquals([...labels]..sort()));
    for (final name in Strings.weekdayShort) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets(
    'shows the weekday labels Sunday first when the setting says so',
    (tester) async {
      harness.settings.values['first_day_of_week'] = '7';
      await mount(tester);

      final rotated = Strings.weekdayShortStarting(DateTime.sunday);
      for (final name in rotated) {
        expect(find.text(name), findsOneWidget);
      }
      final labels = [
        for (final name in rotated) tester.getTopLeft(find.text(name)).dx,
      ];
      expect(labels, orderedEquals([...labels]..sort()));
    },
  );

  testWidgets('shows one cell per day of the month', (tester) async {
    await mount(tester);

    expect(find.byType(DayCell), findsNWidgets(31));
    expect(cell(DateTime(2026, 10, 1)), findsOneWidget);
    expect(cell(DateTime(2026, 10, 31)), findsOneWidget);
    expect(cell(DateTime(2026, 9, 30)), findsNothing);
    expect(cell(DateTime(2026, 11)), findsNothing);
  });

  testWidgets('lines the days up under their weekday', (tester) async {
    await mount(tester);

    double centerX(DateTime day) => tester.getCenter(cell(day)).dx;
    double labelX(String name) => tester.getCenter(find.text(name)).dx;

    // 1 October 2026 is a Thursday; the 5th a Monday; the 11th a Sunday.
    expect(centerX(DateTime(2026, 10, 1)), closeTo(labelX('Thu'), 1));
    expect(centerX(DateTime(2026, 10, 5)), closeTo(labelX('Mon'), 1));
    expect(centerX(DateTime(2026, 10, 11)), closeTo(labelX('Sun'), 1));
    // The 8th is one row below the 1st, in the same column.
    expect(
      centerX(DateTime(2026, 10, 8)),
      closeTo(centerX(DateTime(2026, 10, 1)), 1e-6),
    );
    expect(
      tester.getCenter(cell(DateTime(2026, 10, 8))).dy,
      greaterThan(tester.getCenter(cell(DateTime(2026, 10, 1))).dy),
    );
  });

  testWidgets('today has the disc and past days are muted', (tester) async {
    await mount(tester);
    final colors = tester.element(find.byType(MonthPage)).appColors;

    expect(
      find.descendant(
        of: cell(today),
        matching: find.byKey(const ValueKey('day-cell-today-disc')),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: cell(DateTime(2026, 10, 6)),
              matching: find.text('6'),
            ),
          )
          .style!
          .color,
      colors.muted,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: cell(DateTime(2026, 10, 8)),
              matching: find.text('8'),
            ),
          )
          .style!
          .color,
      colors.ink,
    );
  });

  testWidgets('tapping a day opens it', (tester) async {
    final opened = <DateTime>[];
    await mount(tester, onOpenDay: opened.add);

    await tester.tap(cell(DateTime(2026, 10, 20)));
    await tester.tap(cell(DateTime(2026, 10, 2)));

    expect(opened, [DateTime(2026, 10, 20), DateTime(2026, 10, 2)]);
  });

  testWidgets('the rings show what is planned', (tester) async {
    final handle = tester.ensureSemantics();
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 12),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 12),
      title: 'Lunch walk',
      tone: Tone.life,
      range: const MinuteRange(750, 795),
    );
    await mount(tester);

    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 12))).label,
      'Monday 12 October, Focus 3 hours and Life 45 minutes planned',
    );
    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 13))).label,
      'Tuesday 13 October',
    );
    handle.dispose();
  });

  testWidgets('a new event appears on the grid', (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester);
    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 14))).label,
      'Wednesday 14 October',
    );

    await harness.repository.createEvent(
      day: DateTime(2026, 10, 14),
      title: 'Walk',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 14))).label,
      'Wednesday 14 October, Life 1 hour planned',
    );
    handle.dispose();
  });

  testWidgets('names the three tones in a legend', (tester) async {
    await mount(tester);

    for (final tone in Tone.values) {
      expect(find.text(tone.label), findsOneWidget);
    }
  });

  testWidgets('the legend says how much of each tone the month holds', (
    tester,
  ) async {
    for (final (day, tone, start, end) in [
      (12, Tone.focus, 540, 720),
      (13, Tone.focus, 540, 600),
      (14, Tone.life, 600, 645),
    ]) {
      await harness.repository.createEvent(
        day: DateTime(2026, 10, day),
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, end),
      );
    }
    await mount(tester);

    expect(find.text('4h'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
    // Inbox has nothing planned, so it shows only its name.
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('0m'), findsNothing);
  });

  testWidgets('invites the person to plan a month with nothing in it', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text(Strings.calendarEmptyMonth), findsOneWidget);

    await harness.repository.createEvent(
      day: DateTime(2026, 10, 14),
      title: 'Walk',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.calendarEmptyMonth), findsNothing);
  });

  testWidgets('a month that needs six weeks lays out without overflow', (
    tester,
  ) async {
    // 1 August 2026 is a Saturday and August has 31 days: six rows.
    await mount(tester, month: DateTime(2026, 8));

    expect(find.byType(DayCell), findsNWidgets(31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('other months show no today disc', (tester) async {
    await mount(tester, month: DateTime(2026, 11));

    expect(find.byKey(const ValueKey('day-cell-today-disc')), findsNothing);
    expect(find.byType(DayCell), findsNWidgets(30));
  });

  for (final (name, size) in const [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 17 Pro', Size(402, 874)),
    ('narrow Split View', Size(320, 700)),
    ('iPad 11" portrait', Size(834, 1194)),
    ('iPad 11" landscape', Size(1194, 834)),
  ]) {
    for (final textScale in [1.0, 1.3, 2.0, 3.12]) {
      testWidgets('$name at text ${(textScale * 100).toInt()}% lays out', (
        tester,
      ) async {
        await mount(
          tester,
          month: DateTime(2026, 8),
          size: size,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(DayCell), findsNWidgets(31));
        // Every cell is at least 36 points.
        final cellSize = tester.getSize(find.byType(DayCell).first);
        expect(cellSize.width, greaterThanOrEqualTo(36));
      });
    }
  }
}
