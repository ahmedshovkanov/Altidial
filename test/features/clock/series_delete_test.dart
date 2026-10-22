import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Wednesday's occurrence of a series that also has one on the Tuesday
  /// before and one on the Thursday after.
  ({int series, int before, int on, int after}) addSeries({
    RecurrenceRule? rule,
  }) {
    final series = harness.series.addSeries(
      rule ?? RecurrenceRule.custom({1, 3, 5}, until: DateTime(2026, 12, 31)),
    );
    int add(DateTime date) => harness.repository.addOccurrence(
      seriesId: series,
      day: date,
      title: 'Standup',
      range: const MinuteRange(540, 570),
    );
    return (
      series: series,
      before: add(DateTime(2026, 10, 6)),
      on: add(day),
      after: add(DateTime(2026, 10, 8)),
    );
  }

  Future<void> openDetail(WidgetTester tester, CalendarEvent event) async {
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                EventDetailSheet.show(context, event: event, readOnly: false),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the detail sheet', () {
    testWidgets('says how an occurrence repeats', (tester) async {
      final ids = addSeries();
      await openDetail(tester, harness.repository.eventById(ids.on)!);

      expect(
        find.text('Every Mon, Wed and Fri, until 31 Dec 2026'),
        findsOneWidget,
      );
    });

    testWidgets('says nothing about repeating for a one-off event', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      await openDetail(tester, harness.repository.eventById(id)!);

      expect(find.textContaining('Every'), findsNothing);
      expect(find.textContaining('Weekdays'), findsNothing);
    });

    testWidgets('deleting asks how far, and "this event" closes the sheet', (
      tester,
    ) async {
      final ids = addSeries();
      await openDetail(tester, harness.repository.eventById(ids.on)!);

      await tester.tap(find.text(Strings.delete));
      await tester.pumpAndSettle();
      expect(find.text(Strings.deleteScopeTitle), findsOneWidget);
      expect(find.text(Strings.deleteConfirmTitle), findsNothing);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailSheet), findsNothing);
      expect(harness.repository.eventById(ids.on), isNull);
      expect(harness.repository.eventById(ids.before), isNotNull);
      expect(harness.repository.eventById(ids.after), isNotNull);
      expect(harness.series.deletedFrom, isEmpty);
    });
  });

  group('confirmAndDeleteEvent', () {
    /// Mounts a button that runs the delete on event [eventId] and taps it.
    /// Returns a getter for what the delete resolved to.
    Future<bool? Function()> run(WidgetTester tester, int eventId) async {
      bool? result;
      await tester.pumpWidget(
        harness.app(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                result = await confirmAndDeleteEvent(
                  context,
                  ref,
                  harness.repository.eventById(eventId)!,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('"this and all future events" removes this day and later', (
      tester,
    ) async {
      final ids = addSeries();
      final result = await run(tester, ids.on);

      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(result(), isTrue);
      expect(harness.series.deletedFrom, [ids.on]);
      expect(harness.repository.eventById(ids.on), isNull);
      expect(harness.repository.eventById(ids.after), isNull);
      expect(harness.repository.eventById(ids.before), isNotNull);
    });

    testWidgets('cancelling the question deletes nothing and returns false', (
      tester,
    ) async {
      final ids = addSeries();
      final result = await run(tester, ids.on);

      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(result(), isFalse);
      expect(harness.repository.eventById(ids.on), isNotNull);
      expect(harness.series.deletedFrom, isEmpty);
    });

    testWidgets('a one-off event still gets the plain confirmation', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      await run(tester, id);

      expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);
      expect(find.text(Strings.deleteScopeTitle), findsNothing);
    });
  });
}
