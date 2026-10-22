import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
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

  /// An occurrence of a weekdays series, on [day].
  int addOccurrence({RecurrenceRule? rule}) {
    final seriesId = harness.series.addSeries(
      rule ?? RecurrenceRule.weekdays(),
    );
    return harness.repository.addOccurrence(
      seriesId: seriesId,
      day: day,
      title: 'Standup',
      range: const MinuteRange(540, 570),
    );
  }

  Future<void> openSheet(WidgetTester tester, {int? editing}) async {
    tester.view.physicalSize = const Size(402, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final existing = editing == null
        ? null
        : harness.repository.eventById(editing);
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => EventSheet.show(
              context,
              day: day,
              initialRange: existing?.range ?? const MinuteRange(540, 720),
              existing: existing,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) => tapLabel(tester, Strings.save);

  testWidgets('a new event starts as never repeating', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatNever)),
      matchesSemantics(
        label: Strings.repeatNever,
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
    handle.dispose();
  });

  testWidgets('a repeating event is created as a series', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Standup');
    await tapLabel(tester, Strings.repeatWeekdays);

    await save(tester);

    expect(find.byType(EventSheet), findsNothing);
    final created = harness.series.created.single;
    expect(created.title, 'Standup');
    expect(created.tone, Tone.focus);
    expect(created.range, const MinuteRange(540, 720));
    expect(created.rule, RecurrenceRule.weekdays());
    expect(created.day, day);
    final events = await harness.repository.eventsForDay(day);
    expect(events.single.seriesId, isNotNull);
  });

  testWidgets('an event that does not repeat is created without a series', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Deep work');

    await save(tester);

    expect(harness.series.created, isEmpty);
    final events = await harness.repository.eventsForDay(day);
    expect(events.single.seriesId, isNull);
  });

  testWidgets('custom starts on the day of the week of the event', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Review');
    await tapLabel(tester, Strings.repeatCustom);

    await save(tester);

    expect(
      harness.series.created.single.rule,
      RecurrenceRule.custom({DateTime.wednesday}),
    );
  });

  testWidgets('an end date is saved with the rule', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Standup');
    await tapLabel(tester, Strings.repeatDaily);
    await tapLabel(tester, Strings.repeatEndsOnDate);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await save(tester);

    expect(
      harness.series.created.single.rule,
      RecurrenceRule.daily(until: DateTime(2026, 11, 7)),
    );
  });

  testWidgets('a repeating event on a full day is refused with a message', (
    tester,
  ) async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await harness.repository.createEvent(
        day: day,
        title: 'Existing',
        tone: Tone.focus,
        range: range,
      );
    }
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Fourth');
    await tapLabel(tester, Strings.repeatDaily);

    await save(tester);

    expect(find.text(Strings.ringOverflow), findsOneWidget);
    expect(find.byType(EventSheet), findsOneWidget);
    expect(harness.series.created, isEmpty);
    expect(await harness.repository.eventsForDay(day), hasLength(3));
  });

  group('editing a one-off event', () {
    late int id;

    setUp(() async {
      id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
    });

    testWidgets('saves without asking anything', (tester) async {
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventSheet), findsNothing);
      expect(harness.repository.eventById(id)!.title, 'Renamed');
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('can start repeating, without asking', (tester) async {
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatWeekdays);

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final updated = harness.series.updated.single;
      expect(updated.eventId, id);
      expect(updated.rule, RecurrenceRule.weekdays());
      expect(harness.repository.eventById(id)!.seriesId, isNotNull);
    });
  });

  group('editing an occurrence of a series', () {
    testWidgets('shows the rule of its series', (tester) async {
      final handle = tester.ensureSemantics();
      final id = addOccurrence();
      await openSheet(tester, editing: id);

      expect(
        tester.getSemantics(find.bySemanticsLabel(Strings.repeatWeekdays)),
        matchesSemantics(
          label: Strings.repeatWeekdays,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('saving with nothing changed just closes', (tester) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventSheet), findsNothing);
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('a changed title asks, and "this event" leaves the series', (
      tester,
    ) async {
      final id = addOccurrence();
      final seriesId = harness.repository.eventById(id)!.seriesId;
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      expect(find.text(Strings.editScopeTitle), findsOneWidget);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.byType(EventSheet), findsNothing);
      final event = harness.repository.eventById(id)!;
      expect(event.title, 'Renamed');
      expect(event.seriesId, seriesId);
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('"this and all future events" splits the series', (
      tester,
    ) async {
      final id = addOccurrence();
      final seriesId = harness.repository.eventById(id)!.seriesId;
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      final updated = harness.series.updated.single;
      expect(updated.eventId, id);
      expect(updated.title, 'Renamed');
      expect(updated.rule, RecurrenceRule.weekdays());
      final event = harness.repository.eventById(id)!;
      expect(event.title, 'Renamed');
      expect(event.seriesId, isNot(seriesId));
    });

    testWidgets('a changed time counts as a change', (tester) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == Strings.stepperIncrease(Strings.endLabel),
        ),
      );
      await tester.pump();

      await save(tester);

      expect(find.text(Strings.editScopeTitle), findsOneWidget);
    });

    testWidgets('cancelling the question keeps the sheet and changes nothing', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(EventSheet), findsOneWidget);
      expect(harness.repository.eventById(id)!.title, 'Standup');
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('changing the rule offers only "this and all future"', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatDaily);

      await save(tester);

      expect(find.text(Strings.repeatChangeTitle), findsOneWidget);
      expect(find.text(Strings.scopeThisEvent), findsNothing);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(harness.series.updated.single.rule, RecurrenceRule.daily());
    });

    testWidgets('turning repeat off makes it a one-off from here', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatNever);

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(harness.series.updated.single.rule, const RecurrenceRule.none());
      expect(harness.repository.eventById(id)!.seriesId, isNull);
    });

    testWidgets('a fourth overlapping ring is refused with a message', (
      tester,
    ) async {
      final id = addOccurrence();
      // Three events that overlap each other, starting where the occurrence
      // ends. Stretching the occurrence's end over all three needs a fourth
      // ring.
      for (final range in const [
        MinuteRange(570, 700),
        MinuteRange(575, 700),
        MinuteRange(580, 700),
      ]) {
        await harness.repository.createEvent(
          day: day,
          title: 'Busy',
          tone: Tone.focus,
          range: range,
        );
      }
      await openSheet(tester, editing: id);
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == Strings.stepperIncrease(Strings.endLabel),
          ),
        );
        await tester.pump();
      }

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.text(Strings.ringOverflow), findsOneWidget);
      expect(find.byType(EventSheet), findsOneWidget);
    });
  });
}
