import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

/// The window sizes the Calendar is tested at: the same as the Clock's.
const sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 17 Pro': Size(402, 874),
  'iPad mini portrait': Size(744, 1133),
  'iPad 11" portrait': Size(834, 1194),
  'iPad 11" landscape': Size(1194, 834),
  'iPad 13" portrait': Size(1032, 1376),
  'iPad 13" landscape': Size(1376, 1032),
  'narrow Split View': Size(320, 1000),
};

/// The tab bar's reserve on a phone with no home indicator.
const double shellInset = 84;

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> plan(DateTime day, Tone tone, int start, int minutes) =>
      harness.repository.createEvent(
        day: day,
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, start + minutes),
      );

  /// A month with something on most days, in every combination of tones.
  Future<void> fillMonth(int month) async {
    for (var day = 1; day <= 28; day++) {
      final date = DateTime(2026, month, day);
      await plan(date, Tone.values[day % 3], 360, 30 + (day * 17) % 240);
      if (day.isEven) await plan(date, Tone.values[(day + 1) % 3], 720, 60);
      if (day % 5 == 0) await plan(date, Tone.values[(day + 2) % 3], 1000, 45);
    }
  }

  for (final entry in sizes.entries) {
    final size = entry.value;
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final (label, month, fill) in const [
        ('a busy month', 10, true),
        ('an empty month', 11, false),
        ('a six-week month', 8, true),
      ]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, $label',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (fill) await fillMonth(month);

            // Open on the month under test, with today inside it.
            final today = DateTime(2026, month, 7);
            await tester.pumpWidget(
              harness.app(
                TabBarInset(
                  height: shellInset,
                  child: CalendarScreen(today: today, onOpenDay: (_) {}),
                ),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);

            final cells = find.byType(DayCell);
            final days = DateUtils.getDaysInMonth(2026, month);
            expect(cells, findsNWidgets(days));
            expect(tester.getSize(cells.first).width, greaterThanOrEqualTo(36));

            // The card, and so every column, is inside the window.
            final first = tester.getTopLeft(find.byType(DayCell).first);
            final lastCell = find.byType(DayCell).last;
            final last = tester.getTopRight(lastCell);
            expect(first.dx, greaterThanOrEqualTo(0));
            expect(last.dx, lessThanOrEqualTo(size.width));

            // At normal text nothing should need scrolling: the legend and the
            // empty-month invitation end above the tab bar.
            if (textScale == 1.0) {
              final bottom = tester
                  .getBottomLeft(find.text(Tone.inbox.label))
                  .dy;
              expect(bottom, lessThanOrEqualTo(size.height - shellInset));
              if (!fill) {
                expect(
                  tester
                      .getBottomLeft(find.text(Strings.calendarEmptyMonth))
                      .dy,
                  lessThanOrEqualTo(size.height - shellInset),
                );
              }
            }
          },
        );
      }
    }
  }
}
